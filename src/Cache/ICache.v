`include "Const.v"

module ICache #(parameter CACHE_BIT = `CACHE_BIT,
                CACHE_SIZE = `CACHE_SIZE,
                TAG_BIT = `TAG_BIT)
               (input wire clk_in,                // system clock signal
                input wire rst_in,                // reset signal
                input wire rdy_in,                // ready signal, pause cpu when low
                input wire rob_clear_up,
                input wire wr,                    // 1 for write
                input wire [31:0] addr,           //addr[0] = 0
                input wire [31:0] inst_in,
                output wire is_i_out,
                output wire hit,
                output wire [31:0] inst_out);
reg exist[0:CACHE_SIZE-1];
reg [15:0] buffer [0:CACHE_SIZE-1];
reg [TAG_BIT-1:0] tag [0:CACHE_SIZE-1];
wire [31:0] addr1, addr2;//f(addr)
wire [CACHE_BIT-1:0] index1, index2;//f(addr)
wire [TAG_BIT-1:0] tag1, tag2;//f(addr)
wire hit1, hit2;
wire [15:0] buffer1, buffer2;
wire [15:0] inst_in1, inst_in2;
wire is_i_in    = inst_in[1:0] == 2'b11;
assign is_i_out = inst_out[1:0] == 2'b11;
assign addr1    = addr;
assign addr2    = addr1 + 2;
assign index1   = addr1[CACHE_BIT:1];
assign index2   = addr2[CACHE_BIT:1];
assign tag1     = addr1[31:CACHE_BIT+1];
assign tag2     = addr2[31:CACHE_BIT+1];
assign hit1     = exist[index1] && tag[index1] == tag1;
assign hit2     = exist[index2] && tag[index2] == tag2;
assign buffer1  = buffer[index1];
assign buffer2  = buffer[index2];
assign inst_in1 = inst_in[15:0];
assign inst_in2 = inst_in[31:16];
assign hit      = hit1 && hit2;
assign inst_out = hit ? {buffer2, buffer1} : 32'h0;
integer i;
always @(posedge clk_in)
    if (rst_in)begin
        for (i = 0; i < CACHE_SIZE; i = i + 1)begin
            exist[i]  <= 0;
            buffer[i] <= 16'h0;
            tag[i]    <= 0;
        end
    end
    else if (!rdy_in)begin
        //do nothing
    end
        else if (wr)begin
        exist[index1]  <= 1;
        tag[index1]    <= tag1;
        buffer[index1] <= inst_in1;
        exist[index2]  <= 1;
        tag[index2]    <= tag2;
        buffer[index2] <= inst_in2;
        end
        endmodule
