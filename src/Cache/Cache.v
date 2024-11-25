`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"




module Cache (input wire clk_in,                // system clock signal
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
              input wire [31:0] data_in,        //				st
              output wire to_lsb_ready,         //				ld st
              output wire is_load,
              output wire [31:0] data_out,      //				ld
              input wire [31:0] pc,             // between inst fetcher
              input wire start_fetch,
              output wire fetch_ready,
              output wire [31:0] inst,
              output wire [31:0] inst_addr);
    parameter none = 2'b00,decoder = 2'b01, lsb = 2'b10;
    reg busy;
    reg [1:0]employer;//0 for none,1 for decoder, 2 for lsb
    reg [6:0] op_type;
    reg [2:0] op;
    reg [31:0] addr_reg;
    reg [31:0] load_val;//load/fetch
    reg [31:0] store_val;
    reg [2:0] bytes_remain; // 0 1 2 3
    reg [2:0] bytes_tot; // 0 1 2 3
    wire storing;
    assign storing      = busy && employer == lsb && op_type == `S_TYPE&&bytes_remain;
    assign fetch_ready  = busy && employer == decoder && bytes_remain == 0;
    assign inst         = fetch_ready?{mem_din[7:0], load_val[23:0]}:32'b0;
    assign inst_addr    = fetch_ready?addr_reg:32'b0;
    assign to_lsb_ready = busy && employer == lsb && bytes_remain == 0;
    assign is_load      = to_lsb_ready&&op_type == `LD_TYPE;
    assign mem_wr       = (busy&&bytes_remain&&employer == lsb&&op_type == `S_TYPE)||(!busy&&lsb_ready&&op_type_in == `S_TYPE);
    // assign mem_a     = addr_reg+(bytes_remain-1);//todo 位运算
    function [31:0] get_mem_a;
        input [2:0] bytes_remain_;
        input [31:0] addr_reg_;
        input busy_;
        input lsb_ready_;
        input [31:0] addr_;
        input [31:0] pc_;
        begin
            if (busy_) begin
                case (bytes_remain_)
                    3'b011: get_mem_a  = addr_reg_+1;
                    3'b010: get_mem_a  = addr_reg_+2;
                    3'b001: get_mem_a  = addr_reg_+3;
                    default: get_mem_a = 32'b0;
                endcase
            end
            else begin
                get_mem_a = lsb_ready_?addr_[7:0]:pc_[7:0];
            end
        end
    endfunction
    assign mem_a = get_mem_a(bytes_remain, addr_reg, busy, lsb_ready, addr, pc);
    always @(posedge clk_in) begin
        if (rst_in||(rob_clear_up&&!storing)) begin
            busy         <= 0;
            employer     <= 0;
            op_type      <= 0;
            op           <= 0;
            addr_reg     <= 0;
            load_val     <= 0;
            bytes_remain <= 0;
            bytes_tot    <= 0;
        end
        else if (!rdy_in) begin
            //do nothing
        end
            else if (!busy&&!lsb_ready&&!start_fetch) begin
            employer     <= none;
            op_type      <= 0;
            op           <= 0;
            addr_reg     <= 0;
            load_val     <= 0;
            bytes_remain <= 0;
            bytes_tot    <= 0;
            end
            else if (!busy&&!fetch_ready&&!to_lsb_ready) begin
            if (lsb_ready) begin
                busy         <= 1;
                employer     <= lsb;
                op_type      <= op_type_in;
                op           <= op_in;
                addr_reg     <= addr;
                load_val     <= data_in;
                bytes_remain <= 3'b1<<$unsigned(op[1:0])-1;
                bytes_tot    <= 3'b1<<$unsigned(op[1:0])-1;
            end
            
            else if (start_fetch) begin
            busy         <= 1;
            employer     <= decoder;
            op_type      <= 0;
            op           <= 0;
            addr_reg     <= pc;
            load_val     <= 0;
            bytes_remain <= 3;
            bytes_tot    <= 3;
            end
            
            end
        else begin
            if (bytes_remain == 0) begin
                load_val     <= 0;
                busy         <= 0;
                bytes_remain <= 0;
                bytes_tot    <= 0;
                employer     <= none;
            end
            else
                case (bytes_tot-bytes_remain)
                    3'b010: begin
                        load_val[23:16] <= mem_din;
                        bytes_remain    <= bytes_remain-1;
                    end
                    3'b001: begin
                        load_val[15:8] <= mem_din;
                        bytes_remain   <= bytes_remain-1;
                    end
                    3'b000:begin
                        load_val[7:0] <= mem_din;
                        bytes_remain  <= bytes_remain-1;
                    end
                    default: begin
                        $fatal(1,"bytes_tot-bytes_remain");
                    end
                endcase
            
        end
    end
    
    
    // assign mem_dout = bytes_remain?store_val[bytes_remain<<3-1:bytes_remain<<3-8]:0;
    function [31:0] get_store_val;
        input [2:0] bytes_remain_;
        input [31:0] store_val_;
        input [7:0] bytes_tot_;
        begin
            if (bytes_tot_ == 0) begin
                get_store_val = store_val_[7:0];
            end
            else if (bytes_remain == 0) begin
                get_store_val = 32'b0;
            end
            else
                case (bytes_tot_-bytes_remain)
                    3'b010: get_store_val = store_val_[31:24];
                    3'b001: get_store_val = store_val_[23:16];
                    3'b000: get_store_val = store_val_[15:8];
                endcase
        end
    endfunction
    assign mem_dout    = get_store_val(bytes_remain, store_val, bytes_tot);
    // assign data_out = load_val;
    function [31:0] get_data_out;
        input [2:0] op;
        input [31:0] load_val;
        begin
            case (op)
                3'b000: get_data_out  = {{24{load_val[7]}}, mem_din[7:0]};
                3'b001: get_data_out  = {{16{load_val[15]}}, mem_din[7:0], load_val[7:0]};
                3'b010: get_data_out  = {mem_din[7:0], load_val[23:0]};
                3'b100: get_data_out  = {24'b0, mem_din[7:0]};
                3'b101: get_data_out  = {16'b0, mem_din[7:0], load_val[7:0]};
                default: get_data_out = 32'b0;
            endcase
        end
    endfunction
    assign data_out = to_lsb_ready?get_data_out(op, load_val):32'b0;
endmodule
