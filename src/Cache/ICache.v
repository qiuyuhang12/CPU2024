module ICache (input wire clk_in,                // system clock signal
              input wire rst_in,                // reset signal
              input wire rdy_in,                // ready signal, pause cpu when low
              input wire rob_clear_up,
              input wire [31:0] pc,             // between inst fetcher
              input wire start_fetch,
              output wire hit,
              output wire [31:0] inst,
              output wire [31:0] inst_addr);
    
endmodule
