`include "Const.v"

module Rob(input wire clk_in,                   // system clock signal
           input wire rst_in,                   // reset signal
           input wire rdy_in,                   // ready signal, pause cpu when low
           input wire inst_valid,
           input wire [31:0] inst_addr,
           input wire [31:0] inst,
           input wire [`REG_BIT - 1:0] rd_id,
           input wire [31:0] imm,               //经过sext
           input wire [6:0]op_type,             //大
           input wire [6:0]op,                  //小
           output reg rob_full,
           output reg[31:0] next_pc,
           output wire [3:0] set_reg_id,        //defualt -1//to reg
           output wire [31:0] rob_entry,
           output reg pc_frozen,                //to cdb
           output reg [31:0] issue_value,       //lui/jal/jalr
           output reg [`ROB_BIT:0] issue_entry, //lui/jal/jalr
           output reg jalr_panic,               //to cdb
           );
    parameter ISSUE = 2'b00,WRITE = 2'b01,COMMIT = 2'b10,TODELETECDB = 2'b11;
    //todo 初始 head = 0,tail = 0
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    reg busy[0:`ROB_SIZE-1];
    reg [1:0] state[0:`ROB_SIZE-1];
    reg [31:0] insts[0:`ROB_SIZE-1];
    reg [31:0] insts_addr[0:`ROB_SIZE-1];
    reg [3:0] rd[0:`ROB_SIZE-1];
    reg [31:0] value[0:`ROB_SIZE-1];
    
    //ISSUE
    always @(posedge clk_in) begin
        if (rst_in) begin
        end
        else if (!rdy_in) begin
        end
            //todo:full本次填满且head没有提交
            rob_full < = (tail == head)&&busy[tail];
            // ||(tail == head+1&&busy[tail-1]);
            if (inst_valid) begin
                tail <= tail+1;
                if (inst == 32'h0ff00513) begin
                    //todo:end
                end
                insts[tail]      <= inst;
                insts_addr[tail] <= inst_addr;
                rd[tail]         <= rd_id;
                busy[tail]       <= 1;
                //todo: 由于部分指令没有issue阶段，记得在合适的地方修改正常指令state
                // state[tail] <= ISSUE;
                //LS
                state[tail] < = (op_type == `LD_TYPE||op_type == `S_TYPE||op_type == `LUI||op_type == `JAL)?WRITE:ISSUE;
                if (op_type == `LD_TYPE ||op_type == `S_TYPE) begin
                    // state[tail] <= WRITE;
                end
                
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
            endmodule
