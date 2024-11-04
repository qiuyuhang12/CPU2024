`include "Const.v"

module Alu_common(input wire clk_in,                             // system clock signal
           input wire rst_in,                             // reset signal
           input wire rdy_in,                             // ready signal, pause cpu when low
           input wire new,
           input wire [31:0] vi,
           input wire [31:0] vj,
           input wire [4:0] imm,
           input wire [2:0] op,
           input wire has_imm,
           input wire op_addition,
           input wire [`ROB_SIZE_BIT-1:0]rob_entry,
           output wire [31:0] res,
           output wire ready,
           output wire [`ROB_SIZE_BIT-1:0] rob_entry_out,
           );
    localparam AddSub = 3'b000;
    localparam Sll    = 3'b001;
    localparam Slt    = 3'b010;
    localparam Sltu   = 3'b011;
    localparam Xor    = 3'b100;
    localparam SrlSra = 3'b101;
    localparam Or     = 3'b110;
    localparam And    = 3'b111;
    
    assign sext_imm = {{27{imm[4]}}, imm};
    always @(posedge clk_in)begin
        if (rst_in)begin
            ready         <= 1'b0;
            rob_entry_out <= 0;
            res           <= 0;
            isAddr        <= 1'b0;
        end
        else if (!rdy_in)begin
        end
            else if (!new)begin
            ready <= 1'b0;
            end
        else begin
            ready         <= 1'b1;
            rob_entry_out <= rob_entry;
            if (new)begin
                case(has_imm)
                    1'b0:begin
                        case(op)
                            AddSub:op_addition ? res <= vi - vj : res <= vi + vj;
                            Sll   :res               <= vi << vj[4:0];
                            Slt   :res               <= $signed(vi) < $signed(vj);
                            Sltu  :res               <= $unsigned(vi) < $unsigned(vj);
                            Xor   :res               <= vi ^ vj;
                            SrlSra:op_addition ? $signed(vi) >>> vj[4:0] : vi >> vj[4:0];
                            Or    :res <= vi | vj;
                            And   :res <= vi & vj;
                        endcase
                    end
                    1'b1:begin
                        case(op)
                            AddSub:op_addition ? res <= vi - sext_imm : res <= vi + sext_imm;
                            Sll   :res               <= vi << sext_imm[4:0];
                            Slt   :res               <= $signed(vi) < $signed(sext_imm);
                            Sltu  :res               <= $unsigned(vi) < $unsigned(sext_imm);
                            Xor   :res               <= vi ^ sext_imm;
                            SrlSra:op_addition ? $signed(vi) >>> sext_imm[4:0] : vi >> sext_imm[4:0];
                            Or    :res <= vi | sext_imm;
                            And   :res <= vi & sext_imm;
                        endcase
                    end
                endcase
            end
        end
    end
endmodule //Alu
