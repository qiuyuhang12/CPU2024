`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"

module Reg(input wire clk_in,                          // system clock signal
           input wire rst_in,                          // reset signal
           input wire rdy_in,                          // ready signal, pause cpu when low
           input wire rob_clear_up,
           input wire rob_commit,                      //commit
           input wire debug_rob_empty,
           input wire [4:0] commit_reg_id,
           input wire [31:0] commit_reg_data,
           input wire [`ROB_BIT-1:0] commit_rob_entry,
           input wire issue_pollute,                   //issue
           input wire [4:0] issue_reg_id,
           input wire [`ROB_BIT-1:0] issue_rob_entry,
           input wire [4:0] get_id1,                   //between reg and decoder
           output wire [31:0] val1,
           output wire has_dep1,
           output wire [`ROB_BIT - 1:0] dep1,
           input wire [4:0] get_id2,
           output wire [31:0] val2,
           output wire has_dep2,
           output wire [`ROB_BIT - 1:0] dep2,
           output wire [`ROB_BIT-1:0] get_rob_entry1,  //between rob and reg
           input wire ready1,
           input wire [31:0] value1,
           output wire [`ROB_BIT-1:0] get_rob_entry2,
           input wire ready2,
           input wire [31:0] value2);
    reg [31:0] regs [0:31];
    // reg dirty [0:31];
    reg [31:0] dirty;
    reg [`ROB_BIT-1:0] rob_entry [0:31];
    wire [31:0]debug_regs_8 = regs[8];
    wire has_issue1;
    // assign has_issue1     = dirty[get_id1]||(issue_pollute&&issue_reg_id&&get_id1 == issue_reg_id);
    // assign val1           = has_issue1?value1:regs[get_id1];
    // assign has_dep1       = has_issue1&&!ready1;
    // assign dep1           = issue_reg_id == get_id1?issue_rob_entry:rob_entry[get_id1];
    // assign get_rob_entry1 = dep1;
    // wire has_issue2;
    // assign has_issue2     = dirty[get_id2]||(issue_pollute&&issue_reg_id&&get_id2 == issue_reg_id);
    // assign val2           = has_issue2?value2:regs[get_id2];
    // assign has_dep2       = has_issue2&&!ready2;
    // assign dep2           = issue_reg_id == get_id2?issue_rob_entry:rob_entry[get_id2];
    // assign get_rob_entry2 = dep2;
    assign val1           = has_dep1?value1:regs[get_id1];
    assign has_dep1       = dirty[get_id1]&&!ready1;
    assign dep1           = has_dep1?rob_entry[get_id1]:0;
    assign val2           = has_dep2?value2:regs[get_id2];
    assign has_dep2       = dirty[get_id2]&&!ready2;
    assign dep2           = has_dep2?rob_entry[get_id2]:0;
    assign get_rob_entry1 = rob_entry[get_id1];
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
            //debug
            if (regs[0]||dirty[0]||rob_entry[0]) begin
                $fatal(1,"regs[0] = %d, dirty[0] = %d, rob_entry[0] = %d", regs[0], dirty[0], rob_entry[0]);
            end
            
            if (debug_rob_empty) begin
                for (i = 0; i < 32; i = i + 1) begin
                    if (dirty[i]) begin
                        $fatal(1,"rob_entry[%d] = %d",i,rob_entry[i]);
                    end
                end
            end
            
            if (rob_commit&&commit_reg_id != 0) begin
                if (!(commit_reg_id != 0 || commit_reg_data == 0)) begin
                    $fatal(1,"commit_reg_id = %d, commit_reg_data = %d", commit_reg_id, commit_reg_data);
                end
                regs[commit_reg_id] <= commit_reg_data;
                if (dirty[commit_reg_id] != 1&&issue_rob_entry!= commit_rob_entry) begin
                    $fatal(1,"Assertion failed: dirty[commit_reg_id] should be 1");
                end
                    if (rob_entry[commit_reg_id] == commit_rob_entry) begin
                        dirty[commit_reg_id]     <= 0;
                        rob_entry[commit_reg_id] <= 0;
                    end
            end
            
            if (issue_pollute&&issue_reg_id != 0&&(!rob_commit||issue_rob_entry!= commit_rob_entry)) begin
                if (issue_reg_id == 0) begin
                    $fatal(1,"issue_reg_id = 0");
                end
                dirty[issue_reg_id]     <= 1;
                rob_entry[issue_reg_id] <= issue_rob_entry;
            end
        end
    end

    wire [31:0] debug_regs_0_zero = regs[0];
    wire [31:0] debug_regs_1_ra = regs[1];
    wire [31:0] debug_regs_2_sp = regs[2];
    wire [31:0] debug_regs_3_gp = regs[3];
    wire [31:0] debug_regs_4_tp = regs[4];
    wire [31:0] debug_regs_5_t0 = regs[5];
    wire [31:0] debug_regs_6_t1 = regs[6];
    wire [31:0] debug_regs_7_t2 = regs[7];
    wire [31:0] debug_regs_8_s0 = regs[8];
    wire [31:0] debug_regs_9_s1 = regs[9];
    wire [31:0] debug_regs_10_a0 = regs[10];
    wire [31:0] debug_regs_11_a1 = regs[11];
    wire [31:0] debug_regs_12_a2 = regs[12];
    wire [31:0] debug_regs_13_a3 = regs[13];
    wire [31:0] debug_regs_14_a4 = regs[14];
    wire [31:0] debug_regs_15_a5 = regs[15];
    wire [31:0] debug_regs_16_a6 = regs[16];
    wire [31:0] debug_regs_17_a7 = regs[17];
    wire [31:0] debug_regs_18_s2 = regs[18];
    wire [31:0] debug_regs_19_s3 = regs[19];
    wire [31:0] debug_regs_20_s4 = regs[20];
    wire [31:0] debug_regs_21_s5 = regs[21];
    wire [31:0] debug_regs_22_s6 = regs[22];
    wire [31:0] debug_regs_23_s7 = regs[23];
    wire [31:0] debug_regs_24_s8 = regs[24];
    wire [31:0] debug_regs_25_s9 = regs[25];
    wire [31:0] debug_regs_26_s10 = regs[26];
    wire [31:0] debug_regs_27_s11 = regs[27];
    wire [31:0] debug_regs_28_t3 = regs[28];
    wire [31:0] debug_regs_29_t4 = regs[29];
    wire [31:0] debug_regs_30_t5 = regs[30];
    wire [31:0] debug_regs_31_t6 = regs[31];

    wire debug_dirty_0_zero = dirty[0];
    wire debug_dirty_1_ra = dirty[1];
    wire debug_dirty_2_sp = dirty[2];
    wire debug_dirty_3_gp = dirty[3];
    wire debug_dirty_4_tp = dirty[4];
    wire debug_dirty_5_t0 = dirty[5];
    wire debug_dirty_6_t1 = dirty[6];
    wire debug_dirty_7_t2 = dirty[7];
    wire debug_dirty_8_s0 = dirty[8];
    wire debug_dirty_9_s1 = dirty[9];
    wire debug_dirty_10_a0 = dirty[10];
    wire debug_dirty_11_a1 = dirty[11];
    wire debug_dirty_12_a2 = dirty[12];
    wire debug_dirty_13_a3 = dirty[13];
    wire debug_dirty_14_a4 = dirty[14];
    wire debug_dirty_15_a5 = dirty[15];
    wire debug_dirty_16_a6 = dirty[16];
    wire debug_dirty_17_a7 = dirty[17];
    wire debug_dirty_18_s2 = dirty[18];
    wire debug_dirty_19_s3 = dirty[19];
    wire debug_dirty_20_s4 = dirty[20];
    wire debug_dirty_21_s5 = dirty[21];
    wire debug_dirty_22_s6 = dirty[22];
    wire debug_dirty_23_s7 = dirty[23];
    wire debug_dirty_24_s8 = dirty[24];
    wire debug_dirty_25_s9 = dirty[25];
    wire debug_dirty_26_s10 = dirty[26];
    wire debug_dirty_27_s11 = dirty[27];
    wire debug_dirty_28_t3 = dirty[28];
    wire debug_dirty_29_t4 = dirty[29];
    wire debug_dirty_30_t5 = dirty[30];
    wire debug_dirty_31_t6 = dirty[31];

    wire [`ROB_BIT-1:0] debug_rob_entry_0_zero = rob_entry[0];
    wire [`ROB_BIT-1:0] debug_rob_entry_1_ra = rob_entry[1];
    wire [`ROB_BIT-1:0] debug_rob_entry_2_sp = rob_entry[2];
    wire [`ROB_BIT-1:0] debug_rob_entry_3_gp = rob_entry[3];
    wire [`ROB_BIT-1:0] debug_rob_entry_4_tp = rob_entry[4];
    wire [`ROB_BIT-1:0] debug_rob_entry_5_t0 = rob_entry[5];
    wire [`ROB_BIT-1:0] debug_rob_entry_6_t1 = rob_entry[6];
    wire [`ROB_BIT-1:0] debug_rob_entry_7_t2 = rob_entry[7];
    wire [`ROB_BIT-1:0] debug_rob_entry_8_s0 = rob_entry[8];
    wire [`ROB_BIT-1:0] debug_rob_entry_9_s1 = rob_entry[9];
    wire [`ROB_BIT-1:0] debug_rob_entry_10_a0 = rob_entry[10];
    wire [`ROB_BIT-1:0] debug_rob_entry_11_a1 = rob_entry[11];
    wire [`ROB_BIT-1:0] debug_rob_entry_12_a2 = rob_entry[12];
    wire [`ROB_BIT-1:0] debug_rob_entry_13_a3 = rob_entry[13];
    wire [`ROB_BIT-1:0] debug_rob_entry_14_a4 = rob_entry[14];
    wire [`ROB_BIT-1:0] debug_rob_entry_15_a5 = rob_entry[15];
    wire [`ROB_BIT-1:0] debug_rob_entry_16_a6 = rob_entry[16];
    wire [`ROB_BIT-1:0] debug_rob_entry_17_a7 = rob_entry[17];
    wire [`ROB_BIT-1:0] debug_rob_entry_18_s2 = rob_entry[18];
    wire [`ROB_BIT-1:0] debug_rob_entry_19_s3 = rob_entry[19];
    wire [`ROB_BIT-1:0] debug_rob_entry_20_s4 = rob_entry[20];
    wire [`ROB_BIT-1:0] debug_rob_entry_21_s5 = rob_entry[21];
    wire [`ROB_BIT-1:0] debug_rob_entry_22_s6 = rob_entry[22];
    wire [`ROB_BIT-1:0] debug_rob_entry_23_s7 = rob_entry[23];
    wire [`ROB_BIT-1:0] debug_rob_entry_24_s8 = rob_entry[24];
    wire [`ROB_BIT-1:0] debug_rob_entry_25_s9 = rob_entry[25];
    wire [`ROB_BIT-1:0] debug_rob_entry_26_s10 = rob_entry[26];
    wire [`ROB_BIT-1:0] debug_rob_entry_27_s11 = rob_entry[27];
    wire [`ROB_BIT-1:0] debug_rob_entry_28_t3 = rob_entry[28];
    wire [`ROB_BIT-1:0] debug_rob_entry_29_t4 = rob_entry[29];
    wire [`ROB_BIT-1:0] debug_rob_entry_30_t5 = rob_entry[30];
    wire [`ROB_BIT-1:0] debug_rob_entry_31_t6 = rob_entry[31];
endmodule
