`include "Const.v"

module Pc_predictor (input wire [31:0] now_pc,
                     input wire [31:0] now_inst,
                     input wire [31:0] val1,
                     input wire [31:0] imm,
                     output wire [31:0] next_pc,
                     );
generate
if (now_inst[6:0] == `JAL) begin
    assign next_pc = now_pc + imm;
end
else if (now_inst[6:0] == `JALR) begin
    assign next_pc = val1 + imm;
end
    else if (now_inst[6:0] == `B_TYPE) begin
    assign next_pc = now_pc + imm;
    end
else begin
    assign next_pc = now_pc + 4;
end
endgenerate
endmodule
