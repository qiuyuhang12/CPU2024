`include "Const.v"

module Rs(input wire clk_in,                               // system clock signal
          input wire rst_in,                               // reset signal
          input wire rdy_in,                               // ready signal, pause cpu when low
          input wire rob_clear_up,
          input wire issue_signal,                         // from decoder
          input wire op_type_in,                           //			operation type
          input wire op_in,                                //			operation
          input wire [31:0]reg1_v_in,                      //			register 1 value
          input wire [31:0]reg2_v_in,                      //			register 2 value
          input wire has_dep1_in,                          //			has dependency 1
          input wire has_dep2_in,                          //			has dependency 2
          input wire [`ROB_BITS-1]rob_entry1_in,           //			rob entry 1
          input wire [`ROB_BITS-1]rob_entry2_in,           //			rob entry 2
          input wire [31:0]rd_rob_in,                      //			rob entry for destination register
          input wire [31:0]inst_in,                        //			instruction
          input wire [31:0]inst_addr_in,                   //			instruction address
          input wire isB_in,                               //			is branch instruction
          input wire alu_ready,                            // between reg and alu
          input reg [`ROB_BIT-1:0] finished_alu_rob_entry,
          input wire [31:0] alu_result,
          output reg start_alu,
          output reg [31:0] vi,
          output reg [31:0] vj,
          output reg [2:0] op,
          output reg [6:0] op_type,
          output reg op_addition,
          output reg [`ROB_BIT-1:0] alu_rob_entry,
          input wire lsb_ready,                            //from lsb
          input wire [`ROB_BIT-1:0] lsb_rob_entry,
          input wire [31:0] lsb_value,
          output wire rs_ready,                            //output
          output wire [`ROB_BIT-1:0] rs_rob_entry,
          output wire [31:0] rs_value,
          output wire [31:0] next_pc,
          output reg is_full,
          );
    localparam branch_op = 2'b00,common_op = 2'b01,lsj_op = 2'b10;
    
    reg busy [0:`RS_SIZE-1];
    reg [6:0] op_type [0:`RS_SIZE-1];//[6:0]
    reg [2:0] op [0:`RS_SIZE-1];//[14:12]
    reg [31:0] reg1_v [0:`RS_SIZE-1];
    reg [31:0] reg2_v [0:`RS_SIZE-1];
    reg has_dep1 [0:`RS_SIZE-1];
    reg has_dep2 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rob_entry1 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rob_entry2 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rd_rob [0:`RS_SIZE-1];
    reg [31:0] inst[0:`RS_SIZE-1];
    reg [31:0] inst_addr[0:`RS_SIZE-1];
    reg isB [0:`RS_SIZE-1];
    wire prepared[0:`RS_SIZE-1];

    generate
    genvar i;
    for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
    assign prepared[i] = busy[i]&&!has_dep1[i]&&!has_dep2[i];
    end
    endgenerate

    // wire indicator[0:`RS_SIZE];

    // generate
    // genvar i;
    // assign indicator[0] = 0;
    // for (i = 1; i < = `RS_SIZE; i = i + `RS_SIZE>>3) begin: gen
    // assign indicator[i]   = prepared[i-1]||indicator[i-1];
    // assign indicator[i+1] = prepared[i-1]||prepared[i]||indicator[i-1];
    // assign indicator[i+2] = prepared[i-1]||prepared[i]||prepared[i+1]||indicator[i-1];
    // assign indicator[i+3] = prepared[i-1]||prepared[i]||prepared[i+1]||prepared[i+2]||indicator[i-1];
    // assign indicator[i+4] = prepared[i-1]||prepared[i]||prepared[i+1]||prepared[i+2]||prepared[i+3]||indicator[i-1];
    // assign indicator[i+5] = prepared[i-1]||prepared[i]||prepared[i+1]||prepared[i+2]||prepared[i+3]||prepared[i+4]||indicator[i-1];
    // assign indicator[i+6] = prepared[i-1]||prepared[i]||prepared[i+1]||prepared[i+2]||prepared[i+3]||prepared[i+4]||prepared[i+5]||indicator[i-1];
    // assign indicator[i+7] = prepared[i-1]||prepared[i]||prepared[i+1]||prepared[i+2]||prepared[i+3]||prepared[i+4]||prepared[i+5]||prepared[i+6]||indicator[i-1];
    // end
    // endgenerate

    // wire [`RS_BIT-1:0] tmp[0:`RS_SIZE-1];
    // generate
    // genvar i;
    // for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
    // assign tmp[i] = {`RS_BIT{prepared[i]&&!indicator[i]}}&{i};
    // end
    // endgenerate
    // wire [`RS_BIT-1:0] to_execute;
    // to_execute = tmp[0]^tmp[1]^tmp[2]^tmp[3]^tmp[4]^tmp[5]^tmp[6]^tmp[7]^tmp[8]^tmp[9]^tmp[10]^tmp[11]^tmp[12]^tmp[13]^tmp[14]^tmp[15];
    // generate
    //     genvar i;
    //     for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
    //         assign to_execute[i] = prepared[i]&&!indicator[i];
    //     end
    // endgenerate
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i]       <= 1'b0;
                op_type[i]    <= 7'b0;
                op[i]         <= 3'b0;
                reg1_v[i]     <= 32'b0;
                reg2_v[i]     <= 32'b0;
                has_dep1[i]   <= 1'b0;
                has_dep2[i]   <= 1'b0;
                rob_entry1[i] <= 32'b0;
                rob_entry2[i] <= 32'b0;
                rd_rob[i]     <= 32'b0;
                inst[i]       <= 32'b0;
                inst_addr[i]  <= 32'b0;
                isB[i]        <= 1'b0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
            else if (rob_clear_up) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i]       <= 1'b0;
                op_type[i]    <= 7'b0;
                op[i]         <= 3'b0;
                reg1_v[i]     <= 32'b0;
                reg2_v[i]     <= 32'b0;
                has_dep1[i]   <= 1'b0;
                has_dep2[i]   <= 1'b0;
                rob_entry1[i] <= 32'b0;
                rob_entry2[i] <= 32'b0;
                rd_rob[i]     <= 32'b0;
                inst[i]       <= 32'b0;
                inst_addr[i]  <= 32'b0;
                isB[i]        <= 1'b0;
            end
            end
        else begin
            //listen to broadcast
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                if (busy[i]) begin
                    if (lsb_ready)begin
                        if (rob_entry1[i] == lsb_rob_entry) begin
                            reg1_v[i]   <= lsb_value;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == lsb_rob_entry) begin
                            reg2_v[i]   <= lsb_value;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                    
                    if (alu_ready) begin
                        if (rob_entry1[i] == alu_rob_entry) begin
                            reg1_v[i]   <= alu_result;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == alu_rob_entry) begin
                            reg2_v[i]   <= alu_result;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                end
            end
            //issue
            if (issue_signal) begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
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
                        isB[i]        <= isB_in;
                        break;
                    end
                end
            end
            //execute
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                if (busy[i]&&!has_dep1[i]&&!has_dep2[i]) begin
                    start_alu     <= 1;
                    vi            <= reg1_v[i];
                    vj            <= reg2_v[i];
                    op            <= op[i];
                    op_type       <= op_type[i];
                    op_addition   <= inst[30];
                    alu_rob_entry <= rd_rob[i];
                    busy[i]       <= 1'b0;
                    disable for_loop;
                end
            end
        end
    end
    //broadcast
    assign rs_ready     = alu_ready;
    assign rs_rob_entry = finished_alu_rob_entry;
    assign rs_value     = alu_result;
    //todo:修改rob里不兼容的next_pc
endmodule
