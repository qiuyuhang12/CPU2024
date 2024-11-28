module Controller (input wire clk_in,                // system clock signal
                   input wire rst_in,                // reset signal
                   input wire rdy_in,                // ready signal, pause cpu when low
                   input wire rob_clear_up,
                   output wire mem_wr,               // to ram			write/read signal (1 for write)
                   output wire [31:0] mem_a,         //				memory address
                   output wire [7:0] mem_dout,       //				data input
                   input wire [7:0] mem_din,         //				data output
                   input wire lsb_ready,             // lsb
                   output wire cache_welcome_signal,
                   input wire [6:0] op_type_in,
                   input wire [2:0] op_in,
                   input wire [31:0] addr,
                   input wire [31:0] store_val_in,   //				st
                   output wire to_lsb_ready,         //				ld st
                   output wire is_load,
                   output wire [31:0] load_val_out,  //				ld
                   input wire [31:0] pc,             // between inst fetcher
                   input wire start_fetch,
                   output wire fetch_ready,
                   output wire [31:0] inst,
                   output wire [31:0] inst_addr);
    wire icache_hit;
    wire [31:0] icache_inst_out;
    wire icache_is_c_out;
    ICache icache(.clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .rob_clear_up(rob_clear_up),
    .wr(cache_fetch_ready),
    .addr(cache_fetch_ready?inst_addr:pc),
    .inst_in(cache_inst),
    .is_c_out(icache_is_c_out),
    .hit(icache_hit),
    .inst_out(icache_inst_out));
    Cache cache(.clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .rob_clear_up(rob_clear_up),
    .mem_wr(mem_wr),
    .mem_a(mem_a),
    .mem_dout(mem_dout),
    .mem_din(mem_din),
    .lsb_ready(lsb_ready),
    .cache_welcome_signal(cache_welcome_signal),
    .op_type_in(op_type_in),
    .op_in(op_in),
    .addr(addr),
    .store_val_in(store_val_in),
    .to_lsb_ready(to_lsb_ready),
    .is_load(is_load),
    .load_val_out(load_val_out),
    .start_fetch(start_fetch&&!icache_hit),
    .fetch_ready(cache_fetch_ready),
    .inst(cache_inst),
    .inst_addr(cache_inst_addr),
    .pc(pc));
    wire cache_fetch_ready;
    wire [31:0]cache_inst;
    wire [31:0]cache_inst_addr;
    assign fetch_ready = start_fetch&&icache_hit||cache_fetch_ready;
    assign inst = icache_hit?icache_inst_out:cache_inst;
    assign inst_addr = icache_hit?pc:cache_inst_addr;
    always @(posedge clk_in) begin
        if (icache_hit&&cache_fetch_ready) begin
            $fatal(1,"icache_hit&&cache_fetch_ready");
        end
        // if (pc!=cache_inst_addr) begin
        //     $fatal(1,"pc!=inst_addr");
        // end
        // if (start_fetch&&icache_hit) begin
        //     $display("icache_hit");
        // end
    end
endmodule
