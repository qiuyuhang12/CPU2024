`include "Const.v"

module Lsb (input wire clk_in,                         // system clock signal
            input wire rst_in,                         // reset signal
            input wire rdy_in,                         // ready signal, pause cpu when low
            input wire rob_clear_up,
            output wire lsb_visit_mem,                 //cache
            output wire work_type,                     // 1 for load, 0 for store;(read: 1, write: 0)
            output wire [2:0] word_size,               // 0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes
            output wire [31:0] addr,
            output wire [31:0] data_in,                //ld
            input wire data_out_ready,                 //st
            input wire [31:0] data_out,                //st
            input wire issue_signal,                   // from decoder
            input wire op_type_in,                     // operation type
            input wire op_in,                          // operation
            input wire [31:0]reg1_v_in,                // register 1 value
            input wire [31:0]reg2_v_in,                // register 2 value
            input wire has_dep1_in,                    // has dependency 1
            input wire has_dep2_in,                    // has dependency 2
            input wire [`ROB_BITS-1]rob_entry1_in,     // rob entry 1
            input wire [`ROB_BITS-1]rob_entry2_in,     // rob entry 2
            input wire [31:0]rd_rob_in,                // rob entry for destination register
            input wire [31:0]inst_in,                  // instruction
            input wire [31:0]inst_addr_in,             // instruction address
            input wire rob_empty,                      // from rob
            input wire [`ROB_BIT-1:0] first_rob_entry,
            input wire rs_ready,                       // from rs
            input wire [`ROB_BIT-1:0] rs_rob_entry,
            input wire [31:0] rs_value,
            output wire load_ready,                   // to load
            output wire [`ROB_BIT-1:0] load_rob_entry,
            output wire [31:0] load_value,
            );
            // parameter ISSUE = ;
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    reg mem_executing;
    reg [`ROB_BIT-1:0] mem_executing_rob;
    reg busy[0:`LSB_SIZE-1];
    reg [2:0] state[0:`LSB_SIZE-1];
    reg [6:0] op_type [0:`LSB_SIZE-1];//[6:0]
    reg [2:0] op [0:`LSB_SIZE-1];//[14:12]
    reg [31:0] reg1_v [0:`LSB_SIZE-1];
    reg [31:0] reg2_v [0:`LSB_SIZE-1];
    reg has_dep1 [0:`LSB_SIZE-1];
    reg has_dep2 [0:`LSB_SIZE-1];
    reg [`ROB_BITS-1] rob_entry1 [0:`LSB_SIZE-1];
    reg [`ROB_BITS-1] rob_entry2 [0:`LSB_SIZE-1];
    reg [`ROB_BITS-1] rd_rob [0:`LSB_SIZE-1];
    reg [31:0] value[0:`LSB_SIZE-1];
    reg [31:0] inst[0:`LSB_SIZE-1];
    reg [31:0] inst_addr[0:`LSB_SIZE-1];
    reg isB [0:`LSB_SIZE-1];
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                head              <= 0;
                tail              <= 0;
                mem_executing     <= 0;
                mem_executing_rob <= 0;
                busy[i]           <= 1'b0;
                state[i]          <= 3'b0;
                op_type[i]        <= 7'b0;
                op[i]             <= 3'b0;
                reg1_v[i]         <= 32'b0;
                reg2_v[i]         <= 32'b0;
                has_dep1[i]       <= 1'b0;
                has_dep2[i]       <= 1'b0;
                rob_entry1[i]     <= 0;
                rob_entry2[i]     <= 0;
                rd_rob[i]         <= 0;
                value[i]          <= 0;
                inst[i]           <= 0;
                inst_addr[i]      <= 0;
                isB[i]            <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
            else if (rob_clear_up) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                head          <= 0;
                tail          <= 0;
                mem_executing <= 0;
                busy[i]       <= 1'b0;
                state[i]      <= 3'b0;
                op_type[i]    <= 7'b0;
                op[i]         <= 3'b0;
                reg1_v[i]     <= 32'b0;
                reg2_v[i]     <= 32'b0;
                has_dep1[i]   <= 1'b0;
                has_dep2[i]   <= 1'b0;
                rob_entry1[i] <= 0;
                rob_entry2[i] <= 0;
                rd_rob[i]     <= 0;
                value[i]      <= 0;
                inst[i]       <= 0;
                inst_addr[i]  <= 0;
                isB[i]        <= 0;
            end
            end
        else begin
            //listen to broadcast
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (busy[i]) begin
                    if (rs_ready) begin
                        if (rob_entry1[i] == rs_rob_entry) begin
                            reg1_v[i] <= rs_value;
                        end
                        
                        if (rob_entry2[i] == rs_rob_entry) begin
                            reg2_v[i] <= rs_value;
                        end
                    end
                    
                    if (data_out_ready) begin
                        if (rob_entry1[i] == mem_executing_rob) begin
                            reg1_v[i] <= data_out;
                        end
                        
                        if (rob_entry2[i] == mem_executing_rob) begin
                            reg2_v[i] <= data_out;
                        end
                    end
                end
            end
            //issue
            if (issue_signal) begin
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                    if (!busy[i]) begin
                        busy[i]       <= 1'b1;
                        op_type[i]    <= op_type_in;
                        op[i]         <= op_in;
                        reg1_v[i]     <= reg1_v_in;
                        reg2_v[i]     <= reg2_v_in;
                        has_dep1[i]   <= has_dep1_in;
                        has_dep2[i]   <= has_dep2_in;
                        rob_entry1[i] <= rob_entry1_in;
                        rob_entry2[i] <= rob_entry2_in;
                        rd_rob[i]     <= rd_rob_in;
                        inst[i]       <= inst_in;
                        inst_addr[i]  <= inst_addr_in;
                        break;
                    end
                end
            end
            //execute
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (busy[i]&&!has_dep1[i]&&!has_dep2[i]) begin
                    
                    disable for_loop;
                end
            end
            //broadcast
            // assign rs_ready     = alu_ready;
            // assign rs_rob_entry = finished_alu_rob_entry;
            // assign rs_value     = alu_result;
        end
    end
endmodule
