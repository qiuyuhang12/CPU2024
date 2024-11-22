// RISCV32 CPU top module
// port modification allowed for debugging purposes
`include "Const.v"
`include "Cache/Cache.v"
`include "Decoder.v"
`include "Inst_fetch.v"
`include "Lsb.v"
`include "Reg.v"
`include "Rob.v"
`include "Rs.v"

module cpu(input wire clk_in,               // system clock signal
           input wire rst_in,               // reset signal
           input wire	rdy_in,               // ready signal, pause cpu when low
           input wire [7:0] mem_din,        // data input bus
           output wire [7:0] mem_dout,      // data output bus
           output wire [31:0] mem_a,        // address bus (only 17:0 is used)
           output wire mem_wr,              // write/read signal (1 for write)
           input wire io_buffer_full,       // 1 if uart buffer is full
           output wire [31:0]	dbgreg_dout); // cpu register output (debugging demo)
    //clear
    wire rob_clear_up;
    wire [31:0] clear_next_pc;
    //io
    wire ram_rw;
    assign mem_wr = ~ram_rw;
    //broadcast
    wire lsb_ready;
    wire [31:0] lsb_load_value;
    wire [`ROB_BIT-1:0] lsb_rob_entry;
    wire rs_ready;
    wire [31:0] rs_value;
    wire [`ROB_BIT-1:0] rs_rob_entry;
    //fetch(pre_issue)
    wire should_fetch;
    wire fetch_ready;
    wire jalr_stall;
    wire [31:0] fetch_next_pc;
    wire [31:0] fetch_inst;
    wire [31:0] fetch_inst_addr;
    wire [4:0] fetch_reg1_id;
    wire [4:0] fetch_reg2_id;
    wire [31:0] fetch_reg1_v;
    wire [31:0] fetch_reg2_v;
    wire fetch_has_dep1;
    wire fetch_has_dep2;
    wire [`ROB_BIT-1:0] fetch_rob_entry1;
    wire [`ROB_BIT-1:0] fetch_rob_entry2;
    //issue
    wire issue_signal;
    wire issue_signal_rs;
    wire issue_signal_lsb;
    wire [31:0] inst;
    wire [31:0] inst_addr;
    wire [6:0] op_type;
    wire [2:0] op;
    wire has_dep1;
    wire has_dep2;
    wire [`ROB_BIT-1:0] rob_entry1;
    wire [`ROB_BIT-1:0] rob_entry2;
    wire [31:0] reg1_v;
    wire [31:0] reg2_v;
    wire [31:0] imm;
    wire rd_id;
    wire [`ROB_BIT:0] rd_rob;
    //rob issue reg
    wire rob_issue_reg_signal;
    wire [4:0] issue_reg_id;
    wire [`ROB_BIT-1:0] issue_reg_rob_entry;
    //rob commit reg
    wire rob_commit_reg_signal;
    wire [4:0] commit_reg_id;
    wire [`ROB_BIT-1:0] commit_reg_rob_entry;
    wire [31:0] commit_reg_data;
    //between reg and rob
    wire [31:0] brr_reg_data1;
    wire [`ROB_BIT-1:0] brr_reg_rob_entry1;
    wire brr_ready1;
    wire [31:0] brr_reg_data2;
    wire [`ROB_BIT-1:0] brr_reg_rob_entry2;
    wire brr_ready2;
    //元件basic information
    wire rob_full;
    wire rob_empty;
    wire [`ROB_BIT-1:0] rob_head;
    wire [`ROB_BIT-1:0] rob_tail;
    wire rs_full;
    wire lsb_full;
    //between lsb & cache
    wire lsb_visit_mem;
    wire [31:0] lsb_load_value;
    wire [31:0] lsb_store_value;
    wire [31:0] lsb_addr;
    wire [6:0] lsb_op_type;
    wire [2:0] lsb_op;
    wire cache_ready;
    wire is_load;

    
    Cache cache_inst (
    .clk_in(clk_in),          // input
    .rst_in(rst_in),          // input
    .rdy_in(rdy_in),          // input
    .rob_clear_up(rob_clear_up),    // input
    .ram_rw(ram_rw),          // output
    .ram_addr(mem_a),        // output
    .ram_in(mem_dout),          // output
    .ram_out(mem_din),         // input
    .lsb_ready(lsb_visit_mem),       // input
    .op_type(lsb_op_type),       // input
    .op(lsb_op),                 // input
    .addr(lsb_addr),             // input
    .data_in(lsb_store_value),   // input
    .to_lsb_ready(cache_ready),  // output
    .is_load(is_load),           // output
    .data_out(lsb_load_value)    // output
    .pc(),              // input
    .should_fetch(),    // input
    .fetch_ready(),     // output
    .inst(),            // output
    .inst_addr()        // output
    );
    Decoder decoder_inst (
    .clk_in(clk_in),             // input: system clock signal
    .rst_in(rst_in),             // input: reset signal
    .rdy_in(rdy_in),             // input: ready signal, pause cpu when low
    .wrong_predicted(rob_clear_up),          // input: from rob
    .correct_pc(clear_next_pc),               // input: [31:0]
    .next_pc(),                  // output: [31:0] to inst fetcher
    .jalr_stall(),               // output
    .valid(),                    // input: from inst fetcher
    .inst_addr(),                // input: [31:0]
    .inst(),                     // input: [31:0]
    .pc_predictor_next_pc(),     // output: to inst_fetcher
    .issue_signal(issue_signal),             // output: to rob inst_fetcher
    .issue_signal_rs(issue_signal_rs),          // output: to rs
    .issue_signal_lsb(issue_signal_lsb),         // output: to lsb
    .imm(imm),                      // output: [31:0] 经过sext/直接issue/br的offset
    .op_type(op_type),                  // output: [6:0] operation type
    .op(op),                       // output: [2:0] operation
    .reg1_v(reg1_v),                   // output: [31:0] register 1 value
    .reg2_v(reg2_v),                   // output: [31:0] register 2 value //todo, 有的是imm
    .has_dep1(has_dep1),                 // output: has dependency 1
    .has_dep2(has_dep2),                 // output: has dependency 2
    .rob_entry1(rob_entry1),               // output: [`ROB_BITS-1] rob entry 1
    .rob_entry2(rob_entry2),               // output: [`ROB_BITS-1] rob entry 2
    .rd_id(rd_id),                    // output: [31:0] destination register
    .rd_rob(rd_rob),                   // output: [31:0] rob entry for destination register
    .inst_out(inst),                 // output: [31:0] instruction
    .inst_addr_out(inst_addr),            // output: [31:0] instruction address
    .rob_full(rob_full),                 // input: from rob
    .rob_tail(rob_tail),                 // input: [`ROB_BIT-1:0]
    .rs_full(rs_full),                  // input: from rs
    .lsb_full(lsb_full),                 // input: from lsb
    .get_id1(fetch_reg1_id),                  // output: [4:0] between reg and decoder
    .val1(fetch_reg1_v),                     // input: [31:0]
    .has_dep1_(fetch_has_dep1),                // input: has dependency 1
    .dep1(fetch_rob_entry1),                     // input: [`ROB_BIT - 1:0]
    .get_id2(fetch_reg2_id),                  // output: [4:0]
    .val2(fetch_reg2_v),                     // input: [31:0]
    .has_dep2_(fetch_has_dep2),                // input: has dependency 2
    .dep2(fetch_rob_entry2)                      // input: [`ROB_BIT - 1:0]
    );
    Inst_fetcher inst_fetcher_inst (
    .clk_in(clk_in),               // input: system clock signal
    .rst_in(rst_in),               // input: reset signal
    .rdy_in(rdy_in),               // input: ready signal, pause cpu when low
    .rob_clear_up(rob_clear_up),         // input
    .rob_next_pc(clear_next_pc),          // input: [31:0]
    .pc(),                   // output: [31:0] between cache
    .start_fetch(),          // output
    .fetch_ready(),          // input
    .inst(),                 // input: [31:0]
    .inst_addr(),            // input: [31:0]
    .start_decode(),         // output: between decoder
    .inst_addr_out(inst_addr),        // output: [31:0] between decoder
    .inst_out(inst),             // output: [31:0]
    .pc_predictor_next_pc(), // input
    .issue_signal()          // input
    );
    Lsb lsb_inst (
    .clk_in(clk_in),                         // input: system clock signal
    .rst_in(rst_in),                         // input: reset signal
    .rdy_in(rdy_in),                         // input: ready signal, pause cpu when low
    .rob_clear_up(rob_clear_up),                   // input
    .lsb_visit_mem(lsb_visit_mem),                  // output: cache
    .op_type_out(lsb_op_type),                      // output: 1 for load, 0 for store; (read: 1, write: 0)
    .op_out(lsb_op)                      // output: 0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes
    .addr(lsb_addr),                           // output: [31:0]
    .data_in(lsb_store_value),                        // output: [31:0] st
    .cache_ready(cache_ready),                    // input: ldst
    .is_load(is_load),                        // input
    .data_out(lsb_load_value),                       // input: [31:0] ld
    .issue_signal(issue_signal_lsb),                   // input: from decoder
    .op_type_in(op_type),                     // input: operation type
    .op_in(op),                          // input: operation
    .imm_in(imm),                         // input: [31:0] imm
    .reg1_v_in(reg1_v),                      // input: [31:0] register 1 value
    .reg2_v_in(reg2_v),                      // input: [31:0] register 2 value
    .has_dep1_in(has_dep1),                    // input: has dependency 1
    .has_dep2_in(has_dep2),                    // input: has dependency 2
    .rob_entry1_in(rob_entry1),                  // input: [`ROB_BITS-1] rob entry 1
    .rob_entry2_in(rob_entry2),                  // input: [`ROB_BITS-1] rob entry 2
    .rob_entry_rd_in(rd_rob),                // input: [31:0] rob entry for destination register
    .inst_in(inst),                        // input: [31:0] instruction
    .inst_addr_in(inst_addr),                   // input: [31:0] instruction address
    .rob_empty(rob_empty),                      // input: from rob
    .first_rob_entry(rob_head),                // input: [`ROB_BIT-1:0]
    .rs_ready(rs_ready),                       // input: from rs
    .rs_rob_entry(rs_rob_entry),                   // input: [`ROB_BIT-1:0]
    .rs_value(rs_ready),                       // input: [31:0]
    .ls_ready(lsb_inst),                       // output: output load value
    .ls_rob_entry(lsb_rob_entry),                   // output: [`ROB_BIT-1:0]
    .load_value(lsb_load_value)                      // output: [31:0]
    );
    Reg reg_inst (
    .clk_in(clk_in),                         // input: system clock signal
    .rst_in(rst_in),                         // input: reset signal
    .rdy_in(rdy_in),                         // input: ready signal, pause cpu when low
    .rob_clear_up(rob_clear_up),                   // input
    .rob_commit_reg(rob_commit_reg_signal),         // input
    .commit_reg_id(commit_reg_id),                  // input: [4:0] commit
    .commit_reg_data(commit_reg_data),              // input: [31:0] commit
    .commit_rob_entry(commit_reg_rob_entry),        // input: [`ROB_BIT-1:0] commit
    .rob_issue_reg(rob_issue_reg_signal),           // input
    .issue_reg_id(issue_reg_id),                    // input: [4:0] issue
    .issue_rob_entry(issue_reg_rob_entry)           // input: [`ROB_BIT-1:0] issue
    .get_id1(fetch_reg1_id),                        // input: [4:0] between reg and decoder
    .val1(fetch_reg1_v),               // output: [31:0]
    .has_dep1(fetch_has_dep1),                       // output
    .dep1(fetch_rob_entry1),                           // output: [`ROB_BIT - 1:0]
    .get_id2(fetch_reg2_id),                        // input: [4:0]
    .val2(fetch_reg2_v),                           // output: [31:0]
    .has_dep2(fetch_has_dep2),                       // output
    .dep2(fetch_rob_entry2),                           // output: [`ROB_BIT - 1:0]
    .get_rob_entry1(brr_reg_rob_entry1), // output: [`ROB_BIT-1:0] between rob and reg
    .ready1(brr_ready1),                 // input
    .value1(brr_reg_data1),              // input: [`ROB_BIT-1:0]
    .get_rob_entry2(brr_reg_rob_entry2), // output: [`ROB_BIT-1:0]
    .ready2(brr_ready2),                 // input
    .value2(brr_reg_data2)               // input: [`ROB_BIT-1:0]
    );
    Rob rob_inst (
    .clk_in(clk_in),                           // input: system clock signal
    .rst_in(rst_in),                           // input: reset signal
    .rdy_in(rdy_in),                           // input: ready signal, pause cpu when low
    .rob_full(rob_full),                         // output
    .rob_empty(rob_empty),                        // output
    .rob_head(rob_head),                         // output
    .rob_tail(rob_tail),                         // output
    .clear_up(rob_clear_up),                         // output: wrong_predicted
    .next_pc(clear_next_pc),                          // output: [31:0]
    .inst_valid(issue_signal),                       // input: from decoder
    .inst_addr(inst_addr),                        // input: [31:0]
    .inst(inst),                             // input: [31:0]
    .rd_id(rd_id),                            // input: [`REG_BIT - 1:0]
    .imm(imm),                              // input: [31:0] 经过sext/直接issue/br的offset
    .br_predict_in(),                    // input: 1 jump, 0 not jump
    .op_type(op_type),                          // input: [6:0] 大
    .op(op),                               // input: [2:0] 小
    .rob_issue_reg(rob_issue_reg_signal),                     // output: /issue to reg //default 0
    .issue_reg_id(issue_reg_id),                     // output: [4:0] to reg /issue to reg //default 0
    .issue_rob_entry(issue_reg_rob_entry),                  // output: [31:0]
    .rob_commit(rob_commit_reg_signal),                       // output: /commit to reg //default 0
    .commit_rd_reg_id(commit_reg_id),                 // output: [4:0]
    .commit_rob_entry(commit_reg_rob_entry),                 // output: [`ROB_BIT-1:0]
    .commit_value(commit_reg_data),                     // output: [31:0]
    .rs_ready_bd(rs_ready),                      // input: from rs
    .rs_rob_entry(rs_rob_entry),                     // input: [`ROB_BIT-1:0]
    .rs_value(rs_value),                         // input: [31:0]
    .lsb_ready_bd(lsb_ready),                     // input: from lsb
    .lsb_rob_entry(lsb_rob_entry),                    // input: [`ROB_BIT-1:0]
    .lsb_value(lsb_load_value),                        // input: [31:0]
    .get_rob_entry1(brr_reg_rob_entry1), // input: [`ROB_BIT-1:0] between rob and reg
    .ready1(brr_ready1),                 // output
    .value1(brr_reg_data1),              // output: [`ROB_BIT-1:0]
    .get_rob_entry2(brr_reg_rob_entry2), // input: [`ROB_BIT-1:0]
    .ready2(brr_ready2),                 // output
    .value2(brr_reg_data2)               // output: [`ROB_BIT-1:0]
    );
    Rs rs_inst (
    .clk_in(clk_in),                        // input: system clock signal
    .rst_in(rst_in),                        // input: reset signal
    .rdy_in(rdy_in),                        // input: ready signal, pause cpu when low
    .rob_clear_up(rob_clear_up),                  // input
    .issue_signal(issue_signal_rs),                  // input: from decoder
    .op_type_in(op_type),                    // input: operation type
    .op_in(op),                         // input: operation
    .reg1_v_in(reg1_v),                     // input: [31:0] register 1 value
    .reg2_v_in(reg2_v),                     // input: [31:0] register 2 value
    .has_dep1_in(has_dep1),                   // input: has dependency 1
    .has_dep2_in(has_dep2),                   // input: has dependency 2
    .rob_entry1_in(rob_entry1),                 // input: [`ROB_BITS-1] rob entry 1
    .rob_entry2_in(rob_entry2),                 // input: [`ROB_BITS-1] rob entry 2
    .rd_rob_in(rd_rob),                     // input: [31:0] rob entry for destination register
    .inst_in(inst),                       // input: [31:0] instruction
    .inst_addr_in(inst_addr),                  // input: [31:0] instruction address
    .lsb_ready(lsb_ready),                     // input: from lsb
    .lsb_rob_entry(lsb_rob_entry),                 // input: [`ROB_BIT-1:0]
    .lsb_value(lsb_load_value),                     // input: [31:0]
    .rs_ready(rs_ready),                      // output
    .rs_rob_entry(rs_rob_entry),                  // output: [`ROB_BIT-1:0]
    .rs_value(rs_value),                      // output: [31:0]
    .is_full(rs_full)                 // output
    );
    // implementation goes here
    
    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16] == 2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)
    
    always @(posedge clk_in)
    begin
        if (rst_in)
        begin
            
        end
        else if (!rdy_in)
        begin
            
        end
        else
        begin
            
        end
    end
    
endmodule
