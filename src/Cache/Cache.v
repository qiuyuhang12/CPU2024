`include "../Const.v"

module Cache (input wire clk_in,                      // system clock signal
              input wire rst_in,                      // reset signal
              input wire rdy_in,                      // ready signal, pause cpu when low
              output wire ram_rw,                     // read/write select (read: 1, write: 0)
              output wire [`ADDR_WIDTH-1:0] ram_addr, // memory address
              output wire [7:0] ram_in,               // data input
              input wire [7:0] ram_out,               // data output
              input wire rob_clear_up,
              input wire lsb_ready,                   //lsb
              input wire work_type,                   // 1 for load, 0 for store;(read: 1, write: 0)
              input wire [2:0] word_size,             // 0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes
              input wire [31:0] addr,
              input wire [31:0] data_in,              //ld
              output wire data_out_ready,             //st
              output wire [31:0] data_out,            //st
              input wire [31:0] pc,                   //decoder
              input wire should_fetch,
              output wire inst_ready,
              output wire [31:0] inst,
              );
    
endmodule
