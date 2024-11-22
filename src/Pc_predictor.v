`include "Const.v"

module Pc_predictor (input wire [31:0] now_pc,
                     input wire [31:0] now_inst,
                     input wire [31:0] val1,
                     input wire [31:0] imm,
                     output wire [31:0] next_pc);
generate
case (now_inst[6:0])
    `JAL: begin
        assign next_pc = now_pc + imm;
    end
    `JALR: begin
        assign next_pc = val1 + imm;
    end
    `B_TYPE: begin
        assign next_pc = now_pc + imm;
    end
    default: begin
        assign next_pc = now_pc + 4;
    end
endcase
endgenerate
endmodule
