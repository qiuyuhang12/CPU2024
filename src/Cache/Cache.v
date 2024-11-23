`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"




module Cache (input wire clk_in,                // system clock signal
              input wire rst_in,                // reset signal
              input wire rdy_in,                // ready signal, pause cpu when low
              input wire rob_clear_up,
              output wire ram_rw,               // to ram			read/write select (read: 1, write: 0)
              output wire [31:0] ram_addr,      //				memory address
              output wire [7:0] ram_in,         //				data input
              input wire [7:0] ram_out,         //				data output
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
              input wire should_fetch,
              output wire fetch_ready,
              output wire [31:0] inst,
              output wire [31:0] inst_addr);
    parameter decoder = 0, lsb = 1;
    reg busy;
    reg employer;//0 for decoder, 1 for lsb
    reg [6:0] op_type;
    reg [2:0] op;
    reg [31:0] addr_reg;
    reg [31:0] load_val;//load/fetch
    reg [31:0] store_val;
    reg [2:0] bytes_remain; // 0 1 2 3 4
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
                op_type      <= op_type_in;
                op           <= op_in;
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
                case (bytes_remain)
                    3'b100: begin
                        bytes_remain    <= 3'b011;
                        load_val[31:24] <= ram_out;
                    end
                    3'b011: begin
                        bytes_remain    <= 3'b010;
                        load_val[23:16] <= ram_out;
                    end
                    3'b010: begin
                        bytes_remain   <= 3'b001;
                        load_val[15:8] <= ram_out;
                    end
                    3'b001: begin
                        bytes_remain  <= 3'b000;
                        load_val[7:0] <= ram_out;
                    end
                endcase
            end
        end
    end
    
    assign fetch_ready  = busy && employer == decoder && bytes_remain == 0;
    assign inst         = data_out;
    assign inst_addr    = addr_reg;
    assign to_lsb_ready = busy && employer == lsb && bytes_remain == 0;
    assign is_load      = op_type == `LD_TYPE;
    assign ram_rw       = !busy || employer == decoder || employer == lsb&&op_type == `LD_TYPE;
    assign ram_addr     = addr_reg+4-bytes_remain;//todo 位运算
    // assign ram_in    = bytes_remain?store_val[bytes_remain<<3-1:bytes_remain<<3-8]:0;
    function [31:0] get_store_val;
        input [2:0] bytes_remain_;
        input [31:0] store_val_;
        begin
            case (bytes_remain_)
                3'b100: get_store_val  = store_val_[31:24];
                3'b011: get_store_val  = store_val_[23:16];
                3'b010: get_store_val  = store_val_[15:8];
                3'b001: get_store_val  = store_val_[7:0];
                default: get_store_val = 8'b0;
            endcase
        end
    endfunction
    assign ram_in      = get_store_val(bytes_remain, store_val);
    // assign data_out = load_val;
    function [31:0] get_data_out;
        input [2:0] op;
        input [31:0] load_val;
        begin
            case (op)
                3'b000: get_data_out  = {{24{load_val[7]}}, load_val[7:0]};
                3'b001: get_data_out  = {{16{load_val[15]}}, load_val[15:0]};
                3'b010: get_data_out  = load_val;
                3'b100: get_data_out  = {24'b0, load_val[7:0]};
                3'b101: get_data_out  = {16'b0, load_val[15:0]};
                default: get_data_out = 32'b0;
            endcase
        end
    endfunction
    assign data_out = get_data_out(op, load_val);
endmodule
