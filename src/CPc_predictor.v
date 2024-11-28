//`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"
`include "Const.v"

module CPc_predictor (input wire [31:0] now_pc,
                     input wire [31:0] now_inst,
                     input wire [31:0] val1,
                     input wire [6:0] op_type,
                     input wire [31:0] imm,
                     output wire [31:0] next_pc);
function [31:0] calculate_next_pc(input [31:0] now_pc,input [6:0] now_op_type, input [31:0] val1, input [31:0] imm);
    case (now_op_type)
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
            calculate_next_pc = now_pc + 2;
        end
    endcase
endfunction

assign next_pc = calculate_next_pc(now_pc,op_type, val1, imm);
endmodule
