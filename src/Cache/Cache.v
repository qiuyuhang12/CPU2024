`include "../Const.v"

module Cache (input wire clk_in,                      // system clock signal
              input wire rst_in,                      // reset signal
              input wire rdy_in,                      // ready signal, pause cpu when low
              input wire rob_clear_up,
              output wire ram_rw,                     // to ram			read/write select (read: 1, write: 0)
              output wire [`ADDR_WIDTH-1:0] ram_addr, //				memory address
              output wire [7:0] ram_in,               //				data input
              input wire [7:0] ram_out,               //				data output
              input wire lsb_ready,                   // lsb
              input wire [6:0] op_type,
              input wire [2:0] op,
              input wire [31:0] addr,
              input wire [31:0] data_in,              //				st
              output wire to_lsb_ready,               //				ld st
              output wire is_load,
              output wire [31:0] data_out,            //				ld
              input wire [31:0] pc,                   // between inst fetcher
              input wire should_fetch,
              output wire fetch_ready,
              output wire [31:0] inst,
              output wire [31:0] inst_addr,
              );
    parameter decoder = 0, lsb = 1;
    reg busy;
    reg employer;//0 for decoder, 1 for lsb
    reg [6:0] op_type;
    reg [2:0] op;
    reg [31:0] addr_reg;
    reg [31:0] load_val;//load/fetch
    reg [31:0] store_val;
    reg [2:0] bytes_remain; // 0 1 2 3
    wire storing;
    assign storing = busy && employer == lsb && op_type == `S_TYPE;
    always @(posedge clk_in) begin
        if (rst_in||(rob_clear_up&&!storing)) begin
            busy         <= 0;
            employer     <= 0;
            op_type      <= 0;
            op           <= 0;
            addr_reg     <= 0;
            load_val     <= 0;
            bytes_remain <= 0;
        end
        else if (!rdy_in) begin
            //do nothing
        end
            else if (!busy) begin
            if (lsb_ready) begin
                busy         <= 1;
                employer     <= lsb;
                op_type      <= op_type;
                op           <= op;
                addr_reg     <= addr;
                load_val     <= data_in;
                bytes_remain <= 3'b1<<$unsigned(op[1:0]);
            end
            else if (should_fetch) begin
                busy         <= 1;
                employer     <= decoder;
                op_type      <= 0;
                op           <= 0;
                addr_reg     <= pc;
                load_val     <= 0;
                bytes_remain <= 4;
            end
                end
            else begin
                if (bytes_remain == 0) begin
                    busy <= 0;
                end
                else begin
                    bytes_remain                                  <= bytes_remain - 1;
                    load_val[bytes_remain<<3-1:bytes_remain<<3-7] <= ram_out;
                end
            end
            end
        else begin
        end
        else begin
    end
    assign fetch_ready  = busy && employer == decoder && bytes_remain == 0;
    assign inst         = data_out;
    assign inst_addr    = addr_reg;
    assign to_lsb_ready = busy && employer == lsb && bytes_remain == 0;
    assign is_load      = op_type == `LD_TYPE;
    assign ram_rw       = !busy || employer == decoder || employer == lsb&&op_type == `LD_TYPE;
    assign ram_addr     = addr_reg+4-bytes_remain;//todo 位运算
    assign ram_in       = bytes_remain?store_val[bytes_remain<<3-1:bytes_remain<<3-7]:0;
    // assign data_out  = load_val;
    generate
    case (op)
        3'b000: begin
            assign data_out = {{24{load_val[7]}},load_val[7:0]};
        end
        3'b001: begin
            assign data_out = {{16{load_val[15]}},load_val[15:0]};
        end
        3'b010: begin
            assign data_out = load_val;
        end
        3'b100: begin
            assign data_out = {24'b0,load_val[7:0]};
        end
        3'b101: begin
            assign data_out = {16'b0,load_val[15:0]};
        end
        default:
        assign data_out = 0;
    endcase
    endgenerate
endmodule
