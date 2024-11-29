// //`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"
`include "Const.v"

module Inst_fetcher (input wire clk_in,               // system clock signal
                     input wire rst_in,               // reset signal
                     input wire rdy_in,               // ready signal, pause cpu when low
                     input wire rob_clear_up,
                     input wire [31:0]rob_next_pc,
                     output wire is_i,
                     output reg [31:0] pc,            // between cache
                     output reg start_fetch,
                     input wire fetch_ready,
                     input wire [31:0] inst,
                     input wire [31:0] inst_addr,
                     output reg start_decode,         // between decoder
                     output reg [31:0] inst_addr_out, // between decoder
                     output reg [31:0] inst_out,
                     input wire [31:0] pc_predictor_next_pc,
                     input wire issue_signal);
    wire [31:0]next_pc = rob_clear_up?rob_next_pc:pc_predictor_next_pc;
    assign is_i = inst_out[1:0]==2'b11;
    reg active_inst_unissued;
    always @(posedge clk_in) begin
        if (rst_in) begin
            pc                   <= 0;
            start_fetch          <= 1;
            start_decode         <= 0;
            inst_addr_out        <= 0;
            inst_out             <= 0;
            active_inst_unissued <= 0;
        end
        else if (!rdy_in) begin
            //do nothing
        end
            else if (rob_clear_up) begin
            pc                   <= rob_next_pc;
            start_fetch          <= 1;
            start_decode         <= 0;
            inst_addr_out        <= 0;
            inst_out             <= 0;
            active_inst_unissued <= 0;
            end
            else if (fetch_ready) begin
            if (active_inst_unissued) begin
                $fatal(1,"active_inst_unissued");
            end
            start_fetch          <= 0;
            start_decode         <= fetch_ready;
            inst_addr_out        <= inst_addr;
            inst_out             <= inst;
            active_inst_unissued <= 1;
            end
            else if (issue_signal) begin
            pc                   <= next_pc;
            start_fetch          <= 1;
            start_decode         <= 0;
            inst_addr_out        <= 0;
            inst_out             <= 0;
            active_inst_unissued <= 0;
            end
        else begin
        end
    end
endmodule
