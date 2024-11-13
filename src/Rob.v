`include "Const.v"

module Rob(input wire clk_in,                            // system clock signal
           input wire rst_in,                            // reset signal
           input wire rdy_in,                            // ready signal, pause cpu when low
           input wire inst_valid,
           input wire [31:0] inst_addr,
           input wire [31:0] inst,
           input wire [`REG_BIT - 1:0] rd_id,
           input wire [31:0] imm,                        //经过sext
           input wire [6:0]op_type,                      //大
           input wire [3:0]op,                           //小
           input wire [`CDB_SIZE-1:0],                   //from reg
           output reg rob_full,
           output reg[31:0] next_pc,
           output wire [3:0] set_reg_id,                 //defualt -1//to reg
           output wire [31:0] rob_entry,
           output reg pc_frozen,                         //to cdb
           output reg jalr_panic,                        //to cdb
           output reg [31:0] issue_value,                //lui/jal/jalr
           output reg [`ROB_BIT:0] issue_entry,          //lui/jal/jalr
           input wire alu_ready,                         //from alu
           input wire [`ROB_BIT-1:0] alu_rob_entry,
           input wire [31:0] alu_value,
           input wire rs_ready,                          //from rs
           input wire [`ROB_BIT-1:0] rs_rob_entry,
           input wire [31:0] rs_value,
           input wire lsb_ready,                         //from lsb
           input wire [`ROB_BIT-1:0] lsb_rob_entry,
           input wire [31:0] lsb_value,
           input wire jal_jalr_ready,                    //from jal/jalr
           input wire [`ROB_BIT-1:0] jal_jalr_rob_entry,
           input wire [31:0] j_next_pc,
           input wire br_ready,                          //from br
           input wire [`ROB_BIT-1:0] br_rob_entry,
           input wire [31:0] br_value,                   //true if should branch
           input wire [31:0] br_next_pc,
           input wire memory_working,                    //from memory
           );
    parameter UNKNOW = 3'b000,ISSUE = 3'b001,WRITE = 3'b010,COMMIT = 3'b011,TODELETECDB = 3'b100;
    //todo 初始 head = 0,tail = 0
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    reg busy[0:`ROB_SIZE-1];
    reg [2:0] state[0:`ROB_SIZE-1];
    reg [31:0] insts[0:`ROB_SIZE-1];
    reg [31:0] insts_addr[0:`ROB_SIZE-1];
    reg [3:0] rd[0:`ROB_SIZE-1];
    reg [31:0] value[0:`ROB_SIZE-1];
    reg branch[0:`ROB_SIZE-1];//true if prediction is right
    //ISSUE
    //todo:有些东西每个周期都要恢复默认
    always @(posedge clk_in)
    begin
        if (rst_in) begin
        end
        else if (!rdy_in) begin
        end
            //todo else 的条件
        else begin
            //todo:full本次填满且head没有提交
            rob_full < = (tail == head)&&busy[tail];
            // ||(tail == head+1&&busy[tail-1]);
            //ISSUE
            if (inst_valid) begin
                tail <= tail+1;
                if (inst == `END_TYPE) begin
                    //todo:end
                end
                insts[tail]      <= inst;
                insts_addr[tail] <= inst_addr;
                rd[tail]         <= rd_id;
                busy[tail]       <= 1;
                //todo: 由于部分指令没有issue阶段，记得在合适的地方修改正常指令state
                // state[tail] <= ISSUE;
                //LS
                state[tail] < = (op_type == `LUI||op_type == `JAL)?WRITE:ISSUE;
                
                if (op_type! = `B_TYPE&&op_type! = `S_TYPE) begin
                    set_reg_id <= rd_id;
                    rob_entry  <= tail;
                end
                
                if (op_type == `B_TYPE) begin
                    pc_frozen <= 1;
                    //todo:predict
                    next_pc     <= inst_addr+imm;
                    value[tail] <= 1;
                end
                
                if (op_type == `LUI) begin
                    value[tail]    <= imm;
                    set_reg_id     <= rd_id;
                    rob_entry      <= tail;
                    // state[tail] <= WRITE;
                    issue_value    <= imm;
                    issue_entry    <= tail;
                end
                
                if (op_type == `JAL||op_type == `JALR) begin
                    value[tail] <= inst_addr+4;
                    set_reg_id  <= rd_id;
                    rob_entry   <= tail;
                end
                
                if (op_type == `JALR) begin
                    jalr_panic <= 1;
                end
                
                if (op_type == `Jal) begin
                    pc_frozen      <= 1;
                    next_pc        <= inst_addr+imm;
                    issue_entry    <= tail;
                    issue_value    <= inst_addr+4;
                    // state[tail] <= WRITE;
                end
            end
        end
    end
    
    //RECIEVE BROADCAST
    always @(posedge clk_in) begin
        if (!rst_in && rdy_in && 1) begin
            if (alu_ready) begin
                assert (busy[alu_rob_entry] == 1&&state[alu_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild alu_rob_entry");
                state[alu_rob_entry] <= WRITE;
                value[alu_rob_entry] <= alu_value;
            end
            
            if (rs_ready) begin
                assert (busy[rs_rob_entry] == 1&&state[rs_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild rs_rob_entry");
                state[rs_rob_entry] <= WRITE;
                value[rs_rob_entry] <= rs_value;
            end
            
            if (lsb_ready) begin
                assert (busy[lsb_rob_entry] == 1&&state[lsb_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild lsb_rob_entry");
                state[lsb_rob_entry] <= WRITE;
                value[lsb_rob_entry] <= lsb_value;
            end
            
            if (jal_jalr_ready) begin
                assert (busy[jal_jalr_rob_entry] == 1&&state[jal_jalr_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild jal_jalr_rob_entry");
                assert (op_type == `JAL||op_type == `JALR) else $fatal("Assertion failed: jal_jalr unmatched");
                state[jal_jalr_rob_entry] <= WRITE;
                if (op_type == `JALR) begin
                    next_pc    <= j_next_pc;
                    jalr_panic <= 0;
                end
            end
            
            if (br_ready) begin
                assert (busy[br_rob_entry] == 1&&state[br_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild br_rob_entry");
                assert (op_type == `B_TYPE) else $fatal("Assertion failed: br_ready unmatched");
                state[br_rob_entry] <= WRITE;
                branch[br_rob_entry] < = (br_value == value[br_rob_entry]);
                value[br_rob_entry] <= br_next_pc;//from bool to pc value
                //todo:predictor
            end
        end
    end
    
    //STEP
    always @(posedge clk_in) begin
        if (!rst_in && rdy_in) begin
            if (busy[head] == 1) begin
                if (state[head] == `COMMIT&&(op_type[head] == `S_TYPE||op_type[head] == `B_TYPE)) begin
                    busy[head] <= 0;
                    head       <= head+1;
                    //DEBUG:
                    state[head]      <= UNKNOW;
                    insts[head]      <= 32'h0;
                    insts_addr[head] <= 32'h0;
                    rd[head]         <= 4'hf;
                    value[head]      <= 32'h0;
                    branch[head]     <= 0;
                end
                //    if ((tmp.state == WRITE&&(tmp.inst.tp! = S_TYPE&&tmp.inst.originalOp! = 3)) || tmp.inst.op == opcode::end||(tmp.state == ISSUE&&(tmp.inst.tp == S_TYPE||tmp.inst.originalOp == 3))) {
                
                if ((state[head] == `WRITE&&(op_type[head]! = `S_TYPE&&op_type[head]! = `B_TYPE))||(state[head] == `ISSUE&&(op_type[head] == `S_TYPE||op_type[head] == `B_TYPE))||insts[head] == `END_TYPE)begin
                //TODO:commit
                    end
                else if (op_type[head] == `S_TYPE||op_type[head] == `B_TYPE&&(!memory_working&&op_type[head] == WRITE)) begin
                    state[head] <= COMMIT;
                end
                else begin
                    
                end
                
            end
        end
    end
    
endmodule