`include "Const.v"
`include "Pc_predictor.v"

module Decoder (input wire clk_in,                   // system clock signal
                input wire rst_in,                   // reset signal
                input wire rdy_in,                   // ready signal, pause cpu when low
                input wire valid,
                input wire wrong_predicted,          // from rob
                input wire [31:0] correct_pc,
                output wire [31:0] next_pc,          // to inst queue
                output wire jalr_stall,
                input wire [31:0] inst_addr,         // from inst queue
                input wire [31:0] inst,
                output wire issue_signal,            // to rob inst_queue
                output wire issue_signal_rs,         // to rs
                output wire issue_signal_lsb,        // to lsb
                output wire [31:0] imm,              //			经过sext/直接issue/br的offset
                output wire [6:0] op_type,           //			operation type
                output wire [2:0] op,                //			operation
                output wire [31:0]reg1_v,            //			register 1 value
                output wire [31:0]reg2_v,            //			register 2 value//todo, 有的是imm
                output wire has_dep1,                //			has dependency 1
                output wire has_dep2,                //			has dependency 2
                output wire [`ROB_BITS-1]rob_entry1, //			rob entry 1
                output wire [`ROB_BITS-1]rob_entry2, //			rob entry 2
                output wire [31:0]rd_id,             //			destination register
                output wire [31:0]rd_rob,            //			rob entry for destination register
                output wire [31:0]inst_out,          //			instruction
                output wire [31:0]inst_addr_out,     //			instruction address
                input wire rob_full,                 // from rob
                input wire [`ROB_BIT-1:0] rob_tail,
                input wire rs_full,                  // from rs
                input wire lsb_full,                 // from lsb
                output wire [4:0] get_id1,           // between reg and decoder
                input wire [31:0] val1,
                input wire has_dep1_,                //			has dependency 1
                input wire [`ROB_BIT - 1:0] dep1,
                output wire [4:0] get_id2,
                input wire [31:0] val2,
                input wire has_dep2_,                //			has dependency 2
                input wire [`ROB_BIT - 1:0] dep2,
                );
    assign issue_signal     = !wrong_predicted&&!jalr_stall&&valid && !rob_full && !rs_full && !lsb_full;
    assign issue_signal_rs  = issue_signal&&(op_type == `ALGI_TYPE || op_type == `R_TYPE||op_type == `BR_TYPE);
    assign issue_signal_lsb = issue_signal&&(op_type == `LD_TYPE || op_type == `S_TYPE);
    wire no_rs2;
    assign no_rs2        = op_type == `LUI || op_type == `AUIPC || op_type == `JAL || op_type == `JALR || op_type == `LD_TYPE || op_type == `ALGI_TYPE;
    assign op_type       = inst[6:0];
    assign op            = inst[14:12];
    assign get_id1       = inst[19:15];
    assign get_id2       = inst[24:20];
    assign reg1_v        = val1;
    assign reg2_v        = no_rs2 ? imm : val2;
    assign has_dep1      = has_dep1_;
    assign has_dep2      = no_rs2 ? 0 : has_dep2_;
    assign rob_entry1    = dep1;
    assign rob_entry2    = no_rs2 ? 0 : dep2;
    assign rd_id         = inst[11:7];
    assign rd_rob        = rob_tail;
    assign inst_addr_out = inst_addr;
    assign inst_out      = inst;
    assign jalr_stall    = inst[6:0] == `JALR && has_dep1_;
    wire pc_predictor_next_pc;
    Pc_predictor Pc_predictor_inst(
    .now_pc(inst_addr),
    .now_inst(inst),
    .val1(val1),
    .imm(imm),
    .next_pc(pc_predictor_next_pc));
    assign next_pc = wrong_predicted ? correct_pc : pc_predictor_next_pc;
    generate
    if (op_type == `LUI||op_type == `AUIPC) begin
        assign imm = {inst[31:12], 12'b0};
    end
    else if (op_type == `JAL) begin
        assign imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    end
        else if (op_type == `JALR) begin
        assign imm = {{20{inst[31]}},inst[31:20]};
        end
        else if (op_type == `B_TYPE) begin
        assign imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
        end
        else if (op_type == `LD_TYPE) begin
        assign imm = {{20{inst[31]}}, inst[31:20]};
        end
        else if (op_type == `S_TYPE) begin
        assign imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        end
        else if (op_type == `ALGI_TYPE) begin
        if (op == 3'b001||op == 3'b101) begin
            assign imm = {{20{inst[31]}}, inst[31:20]};
        end
        else begin
            assign imm = {{26{inst[25]}}, inst[25:20]};
        end
        end
        else if (op_type == `R_TYPE) begin
        assign imm = 32'h0;
        end
    else begin
        assign imm = 32'h0;
    end
    endgenerate
endmodule
