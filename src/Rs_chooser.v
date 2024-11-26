`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"

module Rs_chooser (input wire [`RS_SIZE-1:0] prepared,
                   input wire [`RS_SIZE-1:0] busy,
                   output wire full,
                   output wire ready,
                   output wire [`RS_BIT-1:0] rs_entry,
                   output wire [`RS_BIT-1:0] issue_entry);
wire [`RS_BIT-1:0] prepared_tree[1:2*`RS_SIZE-1];
wire [`RS_BIT-1:0] leisure_tree[1:2*`RS_SIZE-1];
generate
genvar i;
for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
assign prepared_tree[i+`RS_SIZE] = prepared[i]?i+1:0;
assign leisure_tree[i+`RS_SIZE]  = busy[i]?0:i+1;
end
genvar j;
for (j = 1; j < `RS_SIZE; j = j + 1) begin
    assign prepared_tree[j] = prepared_tree[j<<1]?prepared_tree[j<<1]:prepared_tree[j<<1|1];
    assign leisure_tree[j]  = leisure_tree[j<<1]?leisure_tree[j<<1]:leisure_tree[j<<1|1];
end
endgenerate
wire debug_p1 = prepared_tree[1];
assign ready       = prepared_tree[1]?1:0;
assign rs_entry    = prepared_tree[1]-1;
assign full        = leisure_tree[1]?0:1;
assign issue_entry = leisure_tree[1]-1;
endmodule
