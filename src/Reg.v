`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"

module Reg(input wire clk_in,                         // system clock signal
           input wire rst_in,                         // reset signal
           input wire rdy_in,                         // ready signal, pause cpu when low
           input wire rob_clear_up,
           input wire rob_commit,                 //commit
           input wire [4:0] commit_reg_id,
           input wire [31:0] commit_reg_data,
           input wire [`ROB_BIT-1:0] commit_rob_entry,
           input wire issue_pollute,                  //issue
           input wire [4:0] issue_reg_id,
           input wire [`ROB_BIT-1:0] issue_rob_entry,
           input wire [4:0] get_id1,                  //between reg and decoder
           output wire [31:0] val1,
           output wire has_dep1,
           output wire [`ROB_BIT - 1:0] dep1,
           input wire [4:0] get_id2,
           output wire [31:0] val2,
           output wire has_dep2,
           output wire [`ROB_BIT - 1:0] dep2,
           output wire [`ROB_BIT-1:0] get_rob_entry1, //between rob and reg
           input wire ready1,
           input wire [31:0] value1,
           output wire [`ROB_BIT-1:0] get_rob_entry2,
           input wire ready2,
           input wire [31:0] value2);
    reg [31:0] regs [0:31];
    // reg dirty [0:31];
    reg [31:0] dirty;
    reg [`ROB_BIT-1:0] rob_entry [0:31];
    wire [31:0]debug_regs_8 = regs[1];
    wire has_issue1;
    assign has_issue1     = dirty[get_id1]||(issue_reg_id!= 0&&get_id1 == issue_rob_entry);
    assign val1           = has_issue1?value1:regs[get_id1];
    assign has_dep1       = has_issue1&&!ready1;
    assign dep1           = issue_reg_id == get_id1?issue_rob_entry:rob_entry[get_id1];
    assign get_rob_entry1 = rob_entry[get_id1];
    wire has_issue2;
    assign has_issue2     = dirty[get_id2]||(issue_reg_id!= 0&&get_id2 == issue_rob_entry);
    assign val2           = has_issue2?value2:regs[get_id2];
    assign has_dep2       = has_issue2&&!ready2;
    assign dep2           = issue_reg_id == get_id2?issue_rob_entry:rob_entry[get_id2];
    assign get_rob_entry2 = rob_entry[get_id2];
    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i]      <= 0;
                dirty[i]     <= 0;
                rob_entry[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
            else if (rob_clear_up) begin
            for (i = 0; i < 32; i = i + 1) begin
                dirty[i]     <= 0;
                rob_entry[i] <= 0;
            end
            end
        else begin
            if (rob_commit&&commit_reg_id != 0) begin
                if (!(commit_reg_id != 0 || commit_reg_data == 0)) begin
                    $fatal(1,"commit_reg_id = %d, commit_reg_data = %d", commit_reg_id, commit_reg_data);
                end
                regs[commit_reg_id] <= commit_reg_data;
                if (dirty[commit_reg_id] != 1&&issue_rob_entry!=commit_rob_entry) begin
                    $fatal(1,"Assertion failed: dirty[commit_reg_id] should be 1");
                end
                if (rob_entry[commit_reg_id] == commit_rob_entry) begin
                    dirty[commit_reg_id]     <= 0;
                    rob_entry[commit_reg_id] <= 0;
                end
            end
            
            if (issue_pollute&&issue_reg_id != 0&&(!rob_commit||issue_rob_entry!=commit_rob_entry)) begin
                dirty[issue_reg_id]     <= 1;
                rob_entry[issue_reg_id] <= issue_rob_entry;
            end
        end
    end
endmodule
