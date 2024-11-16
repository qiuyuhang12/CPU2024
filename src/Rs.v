`include "Const.v"

module reg(input wire clk_in,       // system clock signal
           input wire rst_in,       // reset signal
           input wire rdy_in,       // ready signal, pause cpu when low
           input wire rob_clear_up,
           );
    localparam branch_op = 2'b00,common_op = 2'b01,lsj_op = 2'b10;
    reg busy [0:`RS_SIZE-1];
    reg [6:0] op_type [0:`RS_SIZE-1];//[6:0]
    reg [2:0] op [0:`RS_SIZE-1];//[14:12]
    reg [31:0] reg1_v [0:`RS_SIZE-1];
    reg [31:0] reg2_v [0:`RS_SIZE-1];
    reg [31:0] imms [0:`RS_SIZE-1];
    reg [31:0] rob_entry1 [0:`RS_SIZE-1];
    reg [31:0] rob_entry2 [0:`RS_SIZE-1];
    reg [31:0] rd_id [0:`RS_SIZE-1];
    reg [31:0] inst[0:`RS_SIZE-1];
    reg [31:0] inst_addr[0:`RS_SIZE-1];
    reg isB [0:`RS_SIZE-1];
    
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i]       <= 1'b0;
                op_type[i]    <= 7'b0;
                op[i]         <= 3'b0;
                reg1_v[i]     <= 32'b0;
                reg2_v[i]     <= 32'b0;
                imms[i]       <= 32'b0;
                rob_entry1[i] <= 32'b0;
                rob_entry2[i] <= 32'b0;
                rd_id[i]      <= 32'b0;
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
                imms[i]       <= 32'b0;
                rob_entry1[i] <= 32'b0;
                rob_entry2[i] <= 32'b0;
                rd_id[i]      <= 32'b0;
                inst[i]       <= 32'b0;
                inst_addr[i]  <= 32'b0;
                isB[i]        <= 1'b0;
            end
            end
        else begin
            
        end
    end
endmodule
