`include "Const.v"

module Rs_chooser (input wire prepared[0:`RS_SIZE-1],
                   output wire [`RS_BIT-1:0] rs_entry,
                   );
wire [`RS_BIT-1:0] tree[1:2*`RS_SIZE-1];
generate
genvar i;
for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
assign tree[i+`RS_SIZE] = prepared[i]?i+1:0;
end
genvar j;
for (j = 1; j < `RS_SIZE; j = j + 1) begin
    assign tree[j] = tree[j<<1]?tree[j<<1]:tree[j<<1|1];
end
endgenerate
assign rs_entry = tree[1]-1;
endmodule
