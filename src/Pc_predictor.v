`include "Const.v"

module Pc_predictor (input wire [31:0] now_pc,
                     input wire [31:0] now_inst,
                     input wire [31:0] val1,
                     input wire [31:0] imm,
                     output wire [31:0] next_pc);
function [31:0] calculate_next_pc(input [31:0] now_pc, input [31:0] now_inst, input [31:0] val1, input [31:0] imm);
    case (now_inst[6:0])
        `JAL: begin
            calculate_next_pc = now_pc + imm;
        end
        `JALR: begin
            calculate_next_pc = val1 + imm;
        end
        `B_TYPE: begin
            calculate_next_pc = now_pc + imm;
        end
        default: begin
            calculate_next_pc = now_pc + 4;
        end
    endcase
endfunction

assign next_pc = calculate_next_pc(now_pc, now_inst, val1, imm);
endmodule
