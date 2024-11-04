`include "Const.v"

module Alu_common(input wire clk_in,                             // system clock signal
                  input wire rst_in,                             // reset signal
                  input wire rdy_in,                             // ready signal, pause cpu when low
                  input wire new,
                  input wire [31:0] vi,
                  input wire [31:0] vj,
                  input wire [12:1] imm,
                  input wire [2:0] op,
                  input wire [31:0] pc,
                  input wire [`ROB_SIZE_BIT-1:0]rob_entry,
                  output wire res,
                  output wire ready,
                  output wire [`ROB_SIZE_BIT-1:0] rob_entry_out,
                  output wire [31:0] pc_out,
                  );
    localparam Beq  = 3'b000;
    localparam Bne  = 3'b001;
    localparam Blt  = 3'b100;
    localparam Bge  = 3'b101;
    localparam Bltu = 3'b110;
    localparam Bgeu = 3'b111;
    
    assign sext_imm = {{19{imm[12]}}, imm, 1'b0};
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
                case(op)
                    Beq :res <= vi == vj;
                    Bne :res <= vi != vj;
                    Blt :res <= $signed(vi) < $signed(vj);
                    Bge :res <= $signed(vi) >= $signed(vj);
                    Bltu:res <= $unsigned(vi) < $unsigned(vj);
                    Bgeu:res <= $unsigned(vi) >= $unsigned(vj);
                endcase
                //todo: pc_out
            end
        end
    end
endmodule //Alu
