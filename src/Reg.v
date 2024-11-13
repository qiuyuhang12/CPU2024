`include "Const.v"

module reg(input wire clk_in,                     // system clock signal
           input wire rst_in,                     // reset signal
           input wire rdy_in,                     // ready signal, pause cpu when low
           input wire rob_clear_up,
           input wire [4:0] commit_reg_id,
           input wire [4:0] commit_reg_data,
           input wire [4:0] commit_rob_entry,
           input wire [4:0] issue_reg_id,
           input wire [4:0] issue_rob_entry,
           input wire [4:0] issue_reg_data,       //only lui/jal
           input wire [4:0] get_id1,
           output wire [31:0] get_val1,
           output wire get_has_dep1,
           output wire [`ROB_BIT - 1:0] get_dep1,
           input wire [4:0] get_id2,
           output wire [31:0] get_val2,
           output wire get_has_dep2,
           output wire [`ROB_BIT - 1:0] get_dep2,
           );
    
endmodule
