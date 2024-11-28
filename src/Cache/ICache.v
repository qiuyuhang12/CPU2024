`include "Const.v"

module ICache #(parameter CACHE_SIZE = `CACHE_SIZE)
               (input wire clk_in,                  // system clock signal
                input wire rst_in,                  // reset signal
                input wire rdy_in,                  // ready signal, pause cpu when low
                input wire rob_clear_up,
                input wire start_fetch,             // between inst fetcher
                input wire [31:0] pc,
                input wire is_c,
                output wire hit,
                output wire [31:0] inst,
                output wire [31:0] inst_addr);
    reg [15:0] buffer [0:CACHE_SIZE-1];     // cache buffer
endmodule
