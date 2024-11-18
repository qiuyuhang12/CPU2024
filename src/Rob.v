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
           input wire [2:0]op,                           //小
           output reg rob_full,
           output reg[31:0] next_pc,
           output wire [4:0] issue_rd_reg_id,            //to reg//defualt 0
           output wire [31:0] rob_entry_issued,
           output reg [4:0] commit_rd_reg_id,
           output reg [31:0] commit_value,               //to reg//todo:broadcast it
           output reg [`ROB_BIT-1:0] commit_rob_entry,   //to reg//todo:broadcast it
           output reg pc_frozen,                         //to cdb
           output reg jalr_panic,                        //to cdb
           output reg [31:0] lj_issue_value,             //lui/jal
           output reg [`ROB_BIT:0] lj_issue_entry,
           input wire rs_ready_bd,                       //from rs
           input wire [`ROB_BIT-1:0] rs_rob_entry,
           input wire [31:0] rs_value,
           input wire lsb_ready_bd,                      //from lsb
           input wire [`ROB_BIT-1:0] lsb_rob_entry,
           input wire [31:0] lsb_value,
           input wire jal_jalr_ready_bd,                 //from jal/jalr
           input wire [`ROB_BIT-1:0] jal_jalr_rob_entry,
           input wire [31:0] j_next_pc,
           input wire br_ready_bd,                       //from br
           input wire [`ROB_BIT-1:0] br_rob_entry,
           input wire [31:0] br_value,                   //true if should branch
           input wire [31:0] br_next_pc,
           input wire memory_working,                    //from memory
           input wire lsb_ready,                         //from lsb
           output reg lsb_commit,                        //to lsb
           output reg clear_up,                          //wrong_predicted_clear_signal
           input wire [`ROB_BIT-1:0] get_rob_entry1,     //between rob and reg
           output wire ready1,
           output wire [`ROB_BIT-1:0] value1,
           input wire [`ROB_BIT-1:0] get_rob_entry2,
           output wire ready2,
           output wire [`ROB_BIT-1:0] value2,
           );
    //todo:去掉对lsb的指示
    assign ready1 = state[get_rob_entry1] == `COMMIT||(rs_ready_bd&&rs_ready_bd == get_rob_entry1)||(lsb_ready_bd&&lsb_ready_bd == get_rob_entry1)||(jal_jalr_ready_bd&&jal_jalr_ready_bd == get_rob_entry1)||(br_ready_bd&&br_ready_bd == get_rob_entry1);
    assign value1 = state[get_rob_entry1] == `COMMIT?value[get_rob_entry1]:((rs_ready_bd&&rs_ready_bd == get_rob_entry1)?rs_value:((lsb_ready_bd&&lsb_ready_bd == get_rob_entry1)?lsb_value:((jal_jalr_ready_bd&&jal_jalr_ready_bd == get_rob_entry1)?j_next_pc:((br_ready_bd&&br_ready_bd == get_rob_entry1)?br_next_pc:32'h0))));
    assign ready2 = state[get_rob_entry2] == `COMMIT||(rs_ready_bd&&rs_ready_bd == get_rob_entry2)||(lsb_ready_bd&&lsb_ready_bd == get_rob_entry2)||(jal_jalr_ready_bd&&jal_jalr_ready_bd == get_rob_entry2)||(br_ready_bd&&br_ready_bd == get_rob_entry2);
    assign value2 = state[get_rob_entry2] == `COMMIT?value[get_rob_entry2]:((rs_ready_bd&&rs_ready_bd == get_rob_entry2)?rs_value:((lsb_ready_bd&&lsb_ready_bd == get_rob_entry2)?lsb_value:((jal_jalr_ready_bd&&jal_jalr_ready_bd == get_rob_entry2)?j_next_pc:((br_ready_bd&&br_ready_bd == get_rob_entry2)?br_next_pc:32'h0))));
    //todo:广播不一定对齐了
    parameter UNKNOW = 3'b000,ISSUE = 3'b001,WRITE = 3'b010,COMMIT = 3'b011;
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
            //todo?
        end
        
        if (rst_in||(clear_up&&rdy_in)) begin
            rob_full         <= 0;
            next_pc          <= 32'h0;
            issue_rd_reg_id  <= 5'h1f;
            rob_entry_issued <= 32'h0;
            commit_rd_reg_id <= 5'h1f;
            commit_value     <= 32'h0;
            commit_rob_entry <= 5'h1f;
            pc_frozen        <= 0;
            jalr_panic       <= 0;
            lj_issue_value   <= 32'h0;
            lj_issue_entry   <= 5'h1f;
            lsb_commit       <= 0;
            clear_up         <= 0;
            head <= 0;
            tail <= 0;
            for (int i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i]       <= 0;
                state[i]      <= UNKNOW;
                insts[i]      <= 32'h0;
                insts_addr[i] <= 32'h0;
                rd[i]         <= 4'hf;
                value[i]      <= 32'h0;
                branch[i]     <= 0;
            end
        end
        //todo else 的条件
        else if (rdy_in)begin
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
                issue_rd_reg_id  <= rd_id;
                rob_entry_issued <= tail;
            end
            
            if (op_type == `B_TYPE) begin
                pc_frozen <= 1;
                //todo:predict
                next_pc     <= inst_addr+imm;
                value[tail] <= 1;
            end
            
            if (op_type == `LUI) begin
                value[tail]      <= imm;
                issue_rd_reg_id  <= rd_id;
                rob_entry_issued <= tail;
                // state[tail]   <= WRITE;
                lj_issue_value   <= imm;
                lj_issue_entry   <= tail;
            end
            
            if (op_type == `JAL||op_type == `JALR) begin
                value[tail]      <= inst_addr+4;
                issue_rd_reg_id  <= rd_id;
                rob_entry_issued <= tail;
            end
            
            if (op_type == `JALR) begin
                jalr_panic <= 1;
            end
            
            if (op_type == `JAL) begin
                pc_frozen      <= 1;
                next_pc        <= inst_addr+imm;
                lj_issue_entry <= tail;
                lj_issue_value <= inst_addr+4;
                // state[tail] <= WRITE;
            end
        end
    end
    end
    
    //RECIEVE BROADCAST
    always @(posedge clk_in) begin
        if (!rst_in && rdy_in && 1) begin
            if (alu_ready_bd) begin
                assert (busy[alu_rob_entry] == 1&&state[alu_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild alu_rob_entry");
                state[alu_rob_entry] <= WRITE;
                value[alu_rob_entry] <= alu_value;
            end
            
            if (rs_ready_bd) begin
                assert (busy[rs_rob_entry] == 1&&state[rs_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild rs_rob_entry");
                state[rs_rob_entry] <= WRITE;
                value[rs_rob_entry] <= rs_value;
            end
            
            if (lsb_ready_bd) begin
                assert (busy[lsb_rob_entry] == 1&&state[lsb_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild lsb_rob_entry");
                state[lsb_rob_entry] <= WRITE;
                value[lsb_rob_entry] <= lsb_value;
            end
            
            if (jal_jalr_ready_bd) begin
                assert (busy[jal_jalr_rob_entry] == 1&&state[jal_jalr_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild jal_jalr_rob_entry");
                assert (op_type == `JAL||op_type == `JALR) else $fatal("Assertion failed: jal_jalr unmatched");
                state[jal_jalr_rob_entry] <= WRITE;
                if (op_type == `JALR) begin
                    next_pc    <= j_next_pc;
                    jalr_panic <= 0;
                end
            end
            
            if (br_ready_bd) begin
                assert (busy[br_rob_entry] == 1&&state[br_rob_entry] == `ISSUE) else $fatal("Assertion failed: wild br_rob_entry");
                assert (op_type == `B_TYPE) else $fatal("Assertion failed: br_ready_bd unmatched");
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
                    if (op_type[head] == `END_TYPE) begin
                        //todo:END
                    end
                    else if (op_type[head] == `S_TYPE||op_type[head] == `LD_TYPE) begin
                        if (!memory_working&&lsb_ready) begin
                            state[head] <= WRITE;
                            lsb_commit  <= 1;
                        end
                    end
                    else begin
                        busy[head] <= 0;
                        head       <= head+1;
                        //DEBUG:
                        state[head]      <= UNKNOW;
                        insts[head]      <= 32'h0;
                        insts_addr[head] <= 32'h0;
                        rd[head]         <= 4'hf;
                        value[head]      <= 32'h0;
                        branch[head]     <= 0;
                        case (op_type[head])
                            `LUI:
                            `AUIPC:
                            `JAL:
                            `JALR:
                            `R_TYPE:
                            `I_TYPE:begin
                                commit_rd_reg_id <= rd[head];
                                commit_value     <= value[head];
                                commit_rob_entry <= head;//todo:如果reg的依赖正是此entry,则将依赖清空。
                            end
                            `B_TYPE:begin
                                if (!branch[head]) begin
                                    clear_up  <= 1;
                                    pc_frozen <= 1;
                                    next_pc   <= value[head];
                                end
                            end
                            default:begin
                                assert (0) else $fatal("commit failed: op_type unmatched");
                            end
                        endcase
                    end
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
