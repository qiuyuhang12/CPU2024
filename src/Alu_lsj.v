`include "Const.v"

module Alu_lsj(input wire clk_in,                             // system clock signal
              input wire rst_in,                             // reset signal
              input wire rdy_in,                             // ready signal, pause cpu when low
              input wire new,
              input wire [31:0] vi,
              input wire [11:0] imm,
              input wire op,                                 //instruction[5] store, jalr:1, load:0
              input wire [`ROB_SIZE_BIT-1:0]rob_entry,
              output wire [31:0] res,
              output wire ready,
              output wire [`ROB_SIZE_BIT-1:0] rob_entry_out,
              );
    assign sext_imm      = {{20{imm[11]}}, imm};
    localparam storeJalr = 1;
    localparam load      = 0;
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
                    storeJalr:res <= (vi + sext_imm)&32'b-1;
                    load:res      <= vi + sext_imm;
                endcase
            end
        end
    end
endmodule //Alu
