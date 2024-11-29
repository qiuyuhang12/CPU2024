// RISCV32 CPU top module
// port modification allowed for debugging purposes
//`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"
`include "Const.v"
// `include "Cache/Cache.v"
// `include "Decoder.v"
// `include "Inst_fetch.v"
// `include "Lsb.v"
// `include "Reg.v"
// `include "Rob.v"
// `include "Rs.v"

module cpu(input wire clk_in,               // system clock signal
           input wire rst_in,               // reset signal
           input wire	rdy_in,               // ready signal, pause cpu when low
           input wire [7:0] mem_din,        // data input bus
           output wire [7:0] mem_dout,      // data output bus
           output wire [31:0] mem_a,        // address bus (only 17:0 is used)
           output wire mem_wr,              // write/read signal (1 for write)
           input wire io_buffer_full,       // 1 if uart buffer is full
           output wire [31:0]	dbgreg_dout); // cpu register output (debugging demo)
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
    
    //clear
    wire rob_clear_up;
    wire [31:0] clear_next_pc;
    //broadcast
    wire lsb_ready;
    wire [31:0] lsb_load_value;
    wire [`ROB_BIT-1:0] lsb_rob_entry;
    wire rs_ready;
    wire [31:0] rs_value;
    wire [`ROB_BIT-1:0] rs_rob_entry;
    //fetch(visit_mem)(inst_fetcher&cache)
    wire should_fetch;
    wire [31:0] pc;
    wire [31:0] fetch_next_pc0;
    wire [31:0] fetch_inst0;
    wire [31:0] fetch_inst_addr0;
    //fetch(pre_issue)(inst_fetcher&decoder)
    wire start_decode;
    wire is_i;
    wire istart_decode=start_decode&&is_i;
    wire cstart_decode=start_decode&&!is_i;
    wire [31:0] next_pc=istart_decode?inext_pc:cnext_pc;
    wire [31:0] cnext_pc;
    wire [31:0] inext_pc;
    wire fetch_ready;
    wire jalr_stall=istart_decode?ijalr_stall:cjalr_stall;
    wire cjalr_stall;
    wire ijalr_stall;
    wire [31:0] fetch_next_pc;
    wire [31:0] fetch_inst;
    wire [31:0] fetch_inst_addr;
    wire [4:0] fetch_reg1_id=istart_decode?ifetch_reg1_id:cfetch_reg1_id;
    wire [4:0] fetch_reg2_id=istart_decode?ifetch_reg2_id:cfetch_reg2_id;
    wire [31:0] fetch_reg1_v;
    wire [31:0] fetch_reg2_v;
    wire fetch_has_dep1;
    wire fetch_has_dep2;
    wire [`ROB_BIT-1:0] fetch_rob_entry1;
    wire [`ROB_BIT-1:0] fetch_rob_entry2;
    wire [4:0] cfetch_reg1_id;
    wire [4:0] cfetch_reg2_id;
    wire [31:0] cfetch_reg1_v;
    wire [31:0] cfetch_reg2_v;
    wire cfetch_has_dep1;
    wire cfetch_has_dep2;
    wire [`ROB_BIT-1:0] cfetch_rob_entry1;
    wire [`ROB_BIT-1:0] cfetch_rob_entry2;
    wire [4:0] ifetch_reg1_id;
    wire [4:0] ifetch_reg2_id;
    wire [31:0] ifetch_reg1_v;
    wire [31:0] ifetch_reg2_v;
    wire ifetch_has_dep1;
    wire ifetch_has_dep2;
    wire [`ROB_BIT-1:0] ifetch_rob_entry1;
    wire [`ROB_BIT-1:0] ifetch_rob_entry2;
    //issue(decoder&rob...)
    wire issue_signal=istart_decode?iissue_signal:cissue_signal;
    wire issue_signal_rs=istart_decode?iissue_signal_rs:cissue_signal_rs;
    wire issue_signal_lsb=istart_decode?iissue_signal_lsb:cissue_signal_lsb;
    wire cissue_signal;
    wire cissue_signal_rs;
    wire cissue_signal_lsb;
    wire iissue_signal;
    wire iissue_signal_rs;
    wire iissue_signal_lsb;
    wire br_predict=istart_decode?ibr_predict:cbr_predict;
    wire cbr_predict;
    wire ibr_predict;
    wire [31:0] inst=istart_decode?iinst:cinst;
    wire [31:0] inst_addr=istart_decode?iinst_addr:cinst_addr;
    wire [31:0] cinst;
    wire [31:0] cinst_addr;
    wire [31:0] iinst;
    wire [31:0] iinst_addr;
    wire [6:0] op_type=istart_decode?iop_type:cop_type;
    wire [2:0] op=istart_decode?iop:cop;
    wire has_dep1=istart_decode?ihas_dep1:chas_dep1;
    wire has_dep2=istart_decode?ihas_dep2:chas_dep2;
    wire [`ROB_BIT-1:0] rob_entry1=istart_decode?irob_entry1:crob_entry1;
    wire [`ROB_BIT-1:0] rob_entry2=istart_decode?irob_entry2:crob_entry2;
    wire [31:0] reg1_v=istart_decode?ireg1_v:creg1_v;
    wire [31:0] reg2_v=istart_decode?ireg2_v:creg2_v;
    wire [31:0] imm=istart_decode?iimm:cimm;
    wire [4:0] rd_id=istart_decode?ird_id:crd_id;
    wire [`ROB_BIT-1:0] rd_rob=istart_decode?ird_rob:crd_rob;
    wire [6:0] cop_type;
    wire [2:0] cop;
    wire chas_dep1;
    wire chas_dep2;
    wire [`ROB_BIT-1:0] crob_entry1;
    wire [`ROB_BIT-1:0] crob_entry2;
    wire [31:0] creg1_v;
    wire [31:0] creg2_v;
    wire [31:0] cimm;
    wire [4:0] crd_id;
    wire [`ROB_BIT-1:0] crd_rob;
    wire [6:0] iop_type;
    wire [2:0] iop;
    wire ihas_dep1;
    wire ihas_dep2;
    wire [`ROB_BIT-1:0] irob_entry1;
    wire [`ROB_BIT-1:0] irob_entry2;
    wire [31:0] ireg1_v;
    wire [31:0] ireg2_v;
    wire [31:0] iimm;
    wire [4:0] ird_id;
    wire [`ROB_BIT-1:0] ird_rob;
    //rob issue reg
    wire issue_pollute_signal;
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
    wire cache_welcome_signal;
    wire lsb_visit_mem;
    wire [31:0] lsb_load_value_from_cache;
    wire [31:0] lsb_store_value;
    wire [31:0] lsb_addr;
    wire [6:0] lsb_op_type;
    wire [2:0] lsb_op;
    wire cache_ready;
    wire is_load;
    
    Controller controller_inst (
    .clk_in(clk_in),          // input
    .rst_in(rst_in),          // input
    .rdy_in(rdy_in),          // input
    .rob_clear_up(rob_clear_up),    // input
    .mem_wr(mem_wr),          // output
    .mem_a(mem_a),        // output
    .mem_dout(mem_dout),          // output
    .mem_din(mem_din),         // input
    .lsb_ready(lsb_visit_mem),       // input
    .cache_welcome_signal(cache_welcome_signal), // output
    .op_type_in(lsb_op_type),       // input
    .op_in(lsb_op),                 // input
    .pc(pc),              // input
    .addr(lsb_addr),             // input
    .store_val_in(lsb_store_value),   // input
    .start_fetch(should_fetch),    // input
    .to_lsb_ready(cache_ready),  // output
    .is_load(is_load),           // output
    .load_val_out(lsb_load_value_from_cache),    // output
    .fetch_ready(fetch_ready),     // output
    .inst(fetch_inst0),            // output
    .inst_addr(fetch_inst_addr0)        // output
    );
    //todo： add i
    Decoder decoder_inst (
    .clk_in(clk_in),             // input: system clock signal
    .rst_in(rst_in),             // input: reset signal
    .rdy_in(rdy_in),             // input: ready signal, pause cpu when low
    .wrong_predicted(rob_clear_up),          // input: from rob
    .correct_pc(clear_next_pc),               // input: [31:0]
    .next_pc(inext_pc),                  // output: [31:0] to inst fetcher
    .jalr_stall(ijalr_stall),               // output
    .inst_addr(fetch_inst_addr),                // input: [31:0]
    .inst(fetch_inst),                     // input: [31:0]
    .start_decode(istart_decode),              // input: start decoder
    .br_predict(ibr_predict),                    // output: to rob
    .issue_signal(iissue_signal),             // output: to rob inst_fetcher
    .issue_signal_rs(iissue_signal_rs),          // output: to rs
    .issue_signal_lsb(iissue_signal_lsb),         // output: to lsb
    .imm(iimm),                      // output: [31:0] 经过sext/直接issue/br的offset
    .op_type(iop_type),                  // output: [6:0] operation type
    .op(iop),                       // output: [2:0] operation
    .reg1_v(ireg1_v),                   // output: [31:0] register 1 value
    .reg2_v(ireg2_v),                   // output: [31:0] register 2 value
    .has_dep1(ihas_dep1),                 // output: has dependency 1
    .has_dep2(ihas_dep2),                 // output: has dependency 2
    .rob_entry1(irob_entry1),               // output: [`ROB_BIT-1] rob entry 1
    .rob_entry2(irob_entry2),               // output: [`ROB_BIT-1] rob entry 2
    .rd_id(ird_id),                    // output: destination register
    .rd_rob(ird_rob),                   // output: [31:0] rob entry for destination register
    .inst_out(iinst),                 // output: [31:0] instruction
    .inst_addr_out(iinst_addr),            // output: [31:0] instruction address
    .rob_full(rob_full),                 // input: from rob
    .rob_tail(rob_tail),                 // input: [`ROB_BIT-1:0]
    .rs_full(rs_full),                  // input: from rs
    .lsb_full(lsb_full),                 // input: from lsb
    .get_id1(ifetch_reg1_id),                  // output: [4:0] between reg and decoder
    .val1(fetch_reg1_v),                     // input: [31:0]
    .has_dep1_(fetch_has_dep1),                // input: has dependency 1
    .dep1(fetch_rob_entry1),                     // input: [`ROB_BIT - 1:0]
    .get_id2(ifetch_reg2_id),                  // output: [4:0]
    .val2(fetch_reg2_v),                     // input: [31:0]
    .has_dep2_(fetch_has_dep2),                // input: has dependency 2
    .dep2(fetch_rob_entry2)                      // input: [`ROB_BIT - 1:0]
    );
    CDecoder cdecoder_inst (
    .clk_in(clk_in),             // input: system clock signal
    .rst_in(rst_in),             // input: reset signal
    .rdy_in(rdy_in),             // input: ready signal, pause cpu when low
    .wrong_predicted(rob_clear_up),          // input: from rob
    .correct_pc(clear_next_pc),               // input: [31:0]
    .next_pc(cnext_pc),                  // output: [31:0] to inst fetcher
    .jalr_stall(cjalr_stall),               // output
    .inst_addr(fetch_inst_addr),                // input: [31:0]
    .inst(fetch_inst),                     // input: [31:0]
    .start_decode(cstart_decode),              // input: start decoder
    .br_predict(cbr_predict),                    // output: to rob
    .issue_signal(cissue_signal),             // output: to rob inst_fetcher
    .issue_signal_rs(cissue_signal_rs),          // output: to rs
    .issue_signal_lsb(cissue_signal_lsb),         // output: to lsb
    .imm(cimm),                      // output: [31:0] 经过sext/直接issue/br的offset
    .op_type(cop_type),                  // output: [6:0] operation type
    .op(cop),                       // output: [2:0] operation
    .reg1_v(creg1_v),                   // output: [31:0] register 1 value
    .reg2_v(creg2_v),                   // output: [31:0] register 2 value
    .has_dep1(chas_dep1),                 // output: has dependency 1
    .has_dep2(chas_dep2),                 // output: has dependency 2
    .rob_entry1(crob_entry1),               // output: [`ROB_BIT-1] rob entry 1
    .rob_entry2(crob_entry2),               // output: [`ROB_BIT-1] rob entry 2
    .rd_id(crd_id),                    // output: destination register
    .rd_rob(crd_rob),                   // output: [31:0] rob entry for destination register
    .inst_out(cinst),                 // output: [31:0] instruction
    .inst_addr_out(cinst_addr),            // output: [31:0] instruction address
    .rob_full(rob_full),                 // input: from rob
    .rob_tail(rob_tail),                 // input: [`ROB_BIT-1:0]
    .rs_full(rs_full),                  // input: from rs
    .lsb_full(lsb_full),                 // input: from lsb
    .get_id1(cfetch_reg1_id),                  // output: [4:0] between reg and decoder
    .val1(fetch_reg1_v),                     // input: [31:0]
    .has_dep1_(fetch_has_dep1),                // input: has dependency 1
    .dep1(fetch_rob_entry1),                     // input: [`ROB_BIT - 1:0]
    .get_id2(cfetch_reg2_id),                  // output: [4:0]
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
    .is_i(is_i),                 // output
    .pc(pc),                   // output: [31:0] between cache
    .start_fetch(should_fetch),          // output
    .fetch_ready(fetch_ready),          // input
    .inst(fetch_inst0),                 // input: [31:0]
    .inst_addr(fetch_inst_addr0),            // input: [31:0]
    .start_decode(start_decode),         // output: between decoder
    .inst_addr_out(fetch_inst_addr),        // output: [31:0] between decoder
    .inst_out(fetch_inst),             // output: [31:0]
    .pc_predictor_next_pc(next_pc), // input
    .issue_signal(issue_signal)          // input
    );
    Lsb lsb_inst (
    .clk_in(clk_in),                         // input: system clock signal
    .rst_in(rst_in),                         // input: reset signal
    .rdy_in(rdy_in),                         // input: ready signal, pause cpu when low
    .lsb_full(lsb_full),                        // output: from lsb
    .rob_clear_up(rob_clear_up),                   // input
    .lsb_visit_mem(lsb_visit_mem),                  // output: cache
    .op_type_out(lsb_op_type),                      // output: 1 for load, 0 for store; (read: 1, write: 0)
    .op_out(lsb_op),                      // output: 0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes
    .store_addr_out(lsb_addr),                           // output: [31:0]
    .store_val_in(lsb_store_value),                        // output: [31:0] st
    .cache_ready(cache_ready),                    // input: ldst
    .cache_welcome_signal(cache_welcome_signal),           // input
    .is_load(is_load),                        // input
    .load_val_out(lsb_load_value_from_cache),                       // input: [31:0] ld
    .issue_signal(issue_signal_lsb),                   // input: from decoder
    .op_type_in(op_type),                     // input: operation type
    .op_in(op),                          // input: operation
    .imm_in(imm),                         // input: [31:0] imm
    .reg1_v_in(reg1_v),                      // input: [31:0] register 1 value
    .reg2_v_in(reg2_v),                      // input: [31:0] register 2 value
    .has_dep1_in(has_dep1),                    // input: has dependency 1
    .has_dep2_in(has_dep2),                    // input: has dependency 2
    .rob_entry1_in(rob_entry1),                  // input: [`ROB_BIT-1] rob entry 1
    .rob_entry2_in(rob_entry2),                  // input: [`ROB_BIT-1] rob entry 2
    .rob_entry_rd_in(rd_rob),                // input: [31:0] rob entry for destination register
    .inst_in(inst),                        // input: [31:0] instruction
    .inst_addr_in(inst_addr),                   // input: [31:0] instruction address
    .rob_empty(rob_empty),                      // input: from rob
    .first_rob_entry(rob_head),                // input: [`ROB_BIT-1:0]
    .rs_ready(rs_ready),                       // input: from rs
    .rs_rob_entry(rs_rob_entry),                   // input: [`ROB_BIT-1:0]
    .rs_value(rs_value),                       // input: [31:0]
    .lsb_ready(lsb_ready),                       // output: output load value
    .ls_rob_entry(lsb_rob_entry),                   // output: [`ROB_BIT-1:0]
    .load_value(lsb_load_value)                      // output: [31:0]
    );
    Reg reg_inst (
    .clk_in(clk_in),                         // input: system clock signal
    .rst_in(rst_in),                         // input: reset signal
    .rdy_in(rdy_in),                         // input: ready signal, pause cpu when low
    .rob_clear_up(rob_clear_up),                   // input
    .rob_commit(rob_commit_reg_signal),         // input
    .debug_rob_empty(rob_empty),                  // input
    .commit_reg_id(commit_reg_id),                  // input: [4:0] commit
    .commit_reg_data(commit_reg_data),              // input: [31:0] commit
    .commit_rob_entry(commit_reg_rob_entry),        // input: [`ROB_BIT-1:0] commit
    .issue_pollute(issue_pollute_signal),           // input
    .issue_reg_id(issue_reg_id),                    // input: [4:0] issue
    .issue_rob_entry(issue_reg_rob_entry),           // input: [`ROB_BIT-1:0] issue
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
    .issue_signal(issue_signal),                       // input: from decoder
    .inst_addr(inst_addr),                        // input: [31:0]
    .inst(inst),                             // input: [31:0]
    .rd_id(rd_id),                            // input: [`REG_BIT - 1:0]
    .imm_in(imm),                              // input: [31:0] 经过sext/直接issue/br的offset
    .br_predict_in(br_predict),                    // input: 1 jump, 0 not jump
    .op_type_in(op_type),                          // input: [6:0] 大
    .op_in(op),                               // input: [2:0] 小
    .issue_pollute(issue_pollute_signal),                     // output: /issue to reg //default 0
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
    .rob_entry1_in(rob_entry1),                 // input: [`ROB_BIT-1] rob entry 1
    .rob_entry2_in(rob_entry2),                 // input: [`ROB_BIT-1] rob entry 2
    .rd_rob_in(rd_rob),                     // input: [31:0] rob entry for destination register
    .inst_in(inst),                       // input: [31:0] instruction
    .inst_addr_in(inst_addr),                  // input: [31:0] instruction address
    .lsb_ready(lsb_ready),                     // input: from lsb
    .lsb_rob_entry(lsb_rob_entry),                 // input: [`ROB_BIT-1:0]
    .lsb_value(lsb_load_value),                     // input: [31:0]
    .rs_ready(rs_ready),                      // output
    .rs_rob_entry(rs_rob_entry),                  // output: [`ROB_BIT-1:0]
    .rs_value(rs_value),                      // output: [31:0]
    .rs_full(rs_full)                 // output
    );
    
    
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
            if (mem_wr&&mem_a>32'h20000&&mem_a!=32'h30000&&mem_a!=32'h30004) begin
                $fatal(1,"Invalid memory address %h", mem_a);
            end
        end
    end
    
endmodule
