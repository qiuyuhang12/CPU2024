`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"

//todo:lsb的提交不一定被cache接受
module Lsb (input wire clk_in,                         // system clock signal
            input wire rst_in,                         // reset signal
            input wire rdy_in,                         // ready signal, pause cpu when low
            output wire lsb_full,                      // from lsb
            input wire rob_clear_up,
            output reg lsb_visit_mem,                  // cache
            output reg [6:0] op_type_out,              // 			1 for load, 0 for store;(read: 1, write: 0)
            output reg [2:0] op_out,                   // 			0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes
            output reg [31:0] addr,
            output reg [31:0] data_in,                 //			st
            input wire cache_ready,                    //			ldst
            input wire cache_welcome_signal,
            input wire is_load,                        //
            input wire [31:0] data_out,                //			ld
            input wire issue_signal,                   // from decoder
            input wire [6:0]op_type_in,                //			operation type
            input wire [2:0]op_in,                     //			operation
            input wire [31:0]imm_in,                   //			imm
            input wire [31:0]reg1_v_in,                //			register 1 value
            input wire [31:0]reg2_v_in,                //			register 2 value
            input wire has_dep1_in,                    //			has dependency 1
            input wire has_dep2_in,                    //			has dependency 2
            input wire [`ROB_BIT-1:0]rob_entry1_in,    //			rob entry 1
            input wire [`ROB_BIT-1:0]rob_entry2_in,    //			rob entry 2
            input wire [`ROB_BIT-1:0]rob_entry_rd_in,  //			rob entry for destination register
            input wire [31:0]inst_in,                  //			instruction
            input wire [31:0]inst_addr_in,             //			instruction address
            input wire rob_empty,                      // from rob
            input wire [`ROB_BIT-1:0] first_rob_entry,
            input wire rs_ready,                       // from rs
            input wire [`ROB_BIT-1:0] rs_rob_entry,
            input wire [31:0] rs_value,
            output wire ls_ready,                      // output load value
            output wire [`ROB_BIT-1:0] ls_rob_entry,
            output wire [31:0] load_value);
    parameter LEISURE  = 2'b00, ISSUED  = 2'b01, EXECUTING  = 2'b11;
    // assign rob_full = ((tail == head) && busy[tail]) || ((tail + 1 == head) && busy[tail - 1] && inst_valid);
    assign lsb_full = ((tail == head) && busy[tail]) || ((tail + 1 == head) && busy[tail - 1]&&issue_signal);
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    reg mem_executing;
    reg [`ROB_BIT-1:0] mem_executing_rob;
    
    
    reg busy[0:`LSB_SIZE-1];
    reg [1:0] state[0:`LSB_SIZE-1];
    reg [6:0] op_type [0:`LSB_SIZE-1];//[6:0]
    reg [2:0] op [0:`LSB_SIZE-1];//[14:12]
    reg [31:0] imm [0:`LSB_SIZE-1];
    reg [31:0] reg1_v [0:`LSB_SIZE-1];
    reg [31:0] reg2_v [0:`LSB_SIZE-1];
    reg has_dep1 [0:`LSB_SIZE-1];
    reg has_dep2 [0:`LSB_SIZE-1];
    reg [`ROB_BIT-1:0] rob_entry1 [0:`LSB_SIZE-1];
    reg [`ROB_BIT-1:0] rob_entry2 [0:`LSB_SIZE-1];
    reg [`ROB_BIT-1:0] rob_entry_rd [0:`LSB_SIZE-1];
    reg [31:0] value[0:`LSB_SIZE-1];
    reg [31:0] inst[0:`LSB_SIZE-1];
    reg [31:0] inst_addr[0:`LSB_SIZE-1];
    
    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            head              <= 0;
            tail              <= 0;
            mem_executing     <= 0;
            mem_executing_rob <= 0;
            lsb_visit_mem     <= 0;
            op_type_out       <= 7'b0;
            op_out            <= 3'b0;
            addr              <= 32'b0;
            data_in           <= 32'b0;
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i]         <= 1'b0;
                state[i]        <= 2'b0;
                op_type[i]      <= 7'b0;
                op[i]           <= 3'b0;
                imm[i]          <= 32'b0;
                reg1_v[i]       <= 32'b0;
                reg2_v[i]       <= 32'b0;
                has_dep1[i]     <= 1'b0;
                has_dep2[i]     <= 1'b0;
                rob_entry1[i]   <= 0;
                rob_entry2[i]   <= 0;
                rob_entry_rd[i] <= 0;
                value[i]        <= 0;
                inst[i]         <= 0;
                inst_addr[i]    <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
            else if (rob_clear_up) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                head            <= 0;
                tail            <= 0;
                mem_executing   <= 0;
                busy[i]         <= 1'b0;
                state[i]        <= 2'b0;
                op_type[i]      <= 7'b0;
                op[i]           <= 3'b0;
                imm[i]          <= 32'b0;
                reg1_v[i]       <= 32'b0;
                reg2_v[i]       <= 32'b0;
                has_dep1[i]     <= 1'b0;
                has_dep2[i]     <= 1'b0;
                rob_entry1[i]   <= 0;
                rob_entry2[i]   <= 0;
                rob_entry_rd[i] <= 0;
                value[i]        <= 0;
                inst[i]         <= 0;
                inst_addr[i]    <= 0;
            end
            end
        else begin
            //listen to broadcast
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (busy[i]) begin
                    if (rs_ready) begin
                        if (rob_entry1[i] == rs_rob_entry) begin
                            reg1_v[i]   <= rs_value;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == rs_rob_entry) begin
                            reg2_v[i]   <= rs_value;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                    
                    if (cache_welcome_signal) begin
                        if (rob_entry1[i] == mem_executing_rob) begin
                            reg1_v[i]   <= data_out;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == mem_executing_rob) begin
                            reg2_v[i]   <= data_out;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                end
            end
            //issue
            if (issue_signal) begin
                tail               <= tail + 1;
                busy[tail]         <= 1'b1;
                op_type[tail]      <= op_type_in;
                op[tail]           <= op_in;
                imm[tail]          <= imm_in;
                reg1_v[tail]       <= reg1_v_in;
                reg2_v[tail]       <= reg2_v_in;
                has_dep1[tail]     <= has_dep1_in;
                has_dep2[tail]     <= has_dep2_in;
                rob_entry1[tail]   <= rob_entry1_in;
                rob_entry2[tail]   <= rob_entry2_in;
                rob_entry_rd[tail] <= rob_entry_rd_in;
                inst[tail]         <= inst_in;
                inst_addr[tail]    <= inst_addr_in;
            end
            //execute
            if (mem_executing&&cache_ready) begin
                mem_executing <= 0;
            end
            
            if (busy[head]&&!has_dep1[head]&&!has_dep2[head]&&!mem_executing) begin
                if (rob_empty) begin
                    $fatal(1,"Error: ROB is empty");
                end
                    if (first_rob_entry == rob_entry_rd[head]||op_type[rob_entry_rd[head]] == `LD_TYPE) begin
                        lsb_visit_mem     <= 1;
                        op_type_out       <= op_type[head];
                        op_out            <= op[head];
                        addr              <= reg1_v[head]+imm[head];
                        data_in           <= reg2_v[head];
                        mem_executing     <= 1;
                        mem_executing_rob <= rob_entry_rd[head];
                        state[head]       <= EXECUTING;
                    end
            end
        end
    end
    //broadcast
    assign ls_ready     = cache_ready&&is_load;
    assign ls_rob_entry = mem_executing_rob;
    assign load_value   = is_load?data_out:0;
endmodule
