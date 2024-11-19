`include "Const.v"

module Alu(input wire clk_in,                       // system clock signal
           input wire rst_in,                       // reset signal
           input wire rdy_in,                       // ready signal, pause cpu when low
           input wire valid,
           input wire [31:0] vi,
           input wire [31:0] vj,
           input wire [2:0] op,
           input wire [6:0] op_type,
           input wire op_addition,
           input wire [`ROB_BIT-1:0]rob_entry,
           output reg ready,
           output reg [31:0] res,
           output reg [`ROB_BIT-1:0] rob_entry_out,
           );
    localparam AddSub = 3'b000, Sll = 3'b001, Slt = 3'b010, Sltu = 3'b011, Xor = 3'b100, SrlSra = 3'b101, Or = 3'b110, And = 3'b111;
    
    localparam Beq = 3'b000, Bne = 3'b001, Blt = 3'b100, Bge = 3'b101, Bltu = 3'b110, Bgeu = 3'b111;
    always @(posedge clk_in)begin
        if (rst_in)begin
            ready         <= 1'b0;
            rob_entry_out <= 0;
            res           <= 0;
            isAddr        <= 1'b0;
        end
        else if (!rdy_in)begin
        end
            else if (!valid)begin
            ready <= 1'b0;
            end
        else begin
            ready         <= 1'b1;
            rob_entry_out <= rob_entry;
            if (valid)begin
                if (op_type == 7'b0010011||op_type == 7'b0110011) begin
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
                else if (op_type == 7'b1100011)
                begin
                    case (op)
                        Beq : res <= vi == vj;
                        Bne : res <= vi != vj;
                        Blt : res <= $signed(vi) < $signed(vj);
                        Bge : res <= $signed(vi) >= $signed(vj);
                        Bltu: res <= $unsigned(vi) < $unsigned(vj);
                        Bgeu: res <= $unsigned(vi) >= $unsigned(vj);
                    endcase
                end
                else begin
                    assert (0) else $display("Alu: op_type not supported");
                end
            end
        end
    end
endmodule //Alu
