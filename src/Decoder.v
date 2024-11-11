`include "Const.v"

module Decoder (input wire clk_in,           // system clock signal
                input wire rst_in,           // reset signal
                input wire rdy_in,           // ready signal, pause cpu when low
                input wire valid,
                input wire [31:0] inst_addr,
                input wire [31:0] inst,
                output wire [6:0] optype,
                output wire [3:0] opcode,
                output wire [`REG_BIT - 1:0] rs1_id,
                output wire [`REG_BIT - 1:0] rs2_id,
                output wire [`REG_BIT - 1:0] rd_id,
                output wire [12:0] imm,
                );
    always @(posedge clk_in) begin
        if (rst_in) begin
            get_rs1_id <= 0;
            get_rs2_id <= 0;
        end
        else if (!rdy_in)begin
        end
            else if (valid) begin
            optype <= inst[6:0];
            opcode <= inst[14:12];
            rs1_id <= inst[19:15];
            rs2_id <= inst[24:20];
            rd_id  <= inst[11:7];
            //todo: imm
            end
            end
            endmodule
