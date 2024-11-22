`include "Const.v"

module Rob(input wire clk_in,                           // system clock signal
           input wire rst_in,                           // reset signal
           input wire rdy_in,                           // ready signal, pause cpu when low
           output wire rob_full,
           output wire rob_empty,
           output wire rob_head,
           output wire rob_tail,
           output wire clear_up,                        // wrong_predicted
           output wire [31:0] next_pc,
           input wire inst_valid,                       // from decoder
           input wire [31:0] inst_addr,
           input wire [31:0] inst,
           input wire [`REG_BIT - 1:0] rd_id,
           input wire [31:0] imm,                       //					经过sext/直接issue/br的offset
           input wire br_predict_in,                    //					1 jump, 0 not jump
           input wire [6:0]op_type,                     //					大
           input wire [2:0]op,                          //					小
           output wire rob_issue_reg,                   // to reg			/issue 			to reg//defualt 0
           output wire [4:0] issue_reg_id,              // 			/issue 			to reg//defualt 0
           output wire [31:0] issue_rob_entry,
           output wire rob_commit,                      //					/commit			to reg//defualt 0
           output wire [4:0] commit_rd_reg_id,
           output wire [`ROB_BIT-1:0] commit_rob_entry,
           output wire [31:0] commit_value,
           input wire rs_ready_bd,                      // from rs
           input wire [`ROB_BIT-1:0] rs_rob_entry,
           input wire [31:0] rs_value,
           input wire lsb_ready_bd,                     // from lsb
           input wire [`ROB_BIT-1:0] lsb_rob_entry,
           input wire [31:0] lsb_value,
           input wire [`ROB_BIT-1:0] get_rob_entry1,    // between rob and reg
           output wire ready1,
           output wire [`ROB_BIT-1:0] value1,
           input wire [`ROB_BIT-1:0] get_rob_entry2,
           output wire ready2,
           output wire [`ROB_BIT-1:0] value2);
    assign ready1 = prepared[get_rob_entry1] || (rs_ready_bd&&rs_ready_bd == get_rob_entry1) ||(lsb_ready_bd&&lsb_ready_bd == get_rob_entry1);
    assign value1 = prepared[get_rob_entry1] ? value[get_rob_entry1]:((rs_ready_bd&&rs_ready_bd == get_rob_entry1)?rs_value:((lsb_ready_bd&&lsb_ready_bd == get_rob_entry1)?lsb_value:32'h0));
    assign ready2 = prepared[get_rob_entry2] || (rs_ready_bd&&rs_ready_bd == get_rob_entry2)||(lsb_ready_bd&&lsb_ready_bd == get_rob_entry2);
    assign value2 = prepared[get_rob_entry2] ? value[get_rob_entry2]:((rs_ready_bd&&rs_ready_bd == get_rob_entry2)?rs_value:((lsb_ready_bd&&lsb_ready_bd == get_rob_entry2)?lsb_value:32'h0));
    //todo:广播不一定对齐了
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    assign rob_head  = head;
    assign rob_tail  = tail;
    assign rob_empty = (head == tail)&&!busy[head];
    assign rob_full  = ((tail == head)&&busy[tail])||((tail+1 == head)&&busy[tail-1]&&inst_valid);
    reg busy[0:`ROB_SIZE-1];
    reg prepared[0:`ROB_SIZE-1];
    reg [31:0] insts[0:`ROB_SIZE-1];
    reg [31:0] insts_addr[0:`ROB_SIZE-1];
    reg [2:0] rd[0:`ROB_SIZE-1];
    reg [31:0] value[0:`ROB_SIZE-1];//value->rd | br is true
    reg br_predict;
    always @(posedge clk_in)
    begin
        if (rst_in||(clear_up&&rdy_in)) begin
            integer i;
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i]       <= 1'b0;
                prepared[i]   <= 1'b0;
                insts[i]      <= 32'h0;
                insts_addr[i] <= 32'h0;
                rd[i]         <= 4'h0;
                value[i]      <= 32'h0;
                br_predict[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
        
        // RECIEVE BROADCAST
        if (rs_ready_bd) begin
            if (!(busy[rs_rob_entry] && !prepared[rs_rob_entry])) begin
                $fatal("Assertion failed: wild rs_rob_entry");
            end
            value[rs_rob_entry]    <= rs_value;
            prepared[rs_rob_entry] <= 1;
        end
        
        if (lsb_ready_bd) begin
            if (!(busy[lsb_rob_entry] && !prepared[lsb_rob_entry])) begin
                $fatal("Assertion failed: wild lsb_rob_entry");
            end
            value[lsb_rob_entry]    <= lsb_value;
            prepared[lsb_rob_entry] <= 1;
        end
        
        //COMMIT
        if (busy[head]&&prepared[head]) begin
            head             <= head+1;
            busy[head]       <= 0;
            prepared[head]   <= 0;
            insts[head]      <= 32'h0;
            insts_addr[head] <= 32'h0;
            rd[head]         <= 3'b0;
            value[head]      <= 32'h0;
            br_predict[head] <= 0;
        end
        
        //ISSUE
        if (inst_valid) begin
            //prepare、value、branch
            tail             <= tail+1;
            busy[tail]       <= 1;
            insts[tail]      <= inst;
            insts_addr[tail] <= inst_addr;
            rd[tail]         <= rd_id;
            prepared[tail]   <= (op_type == `LUI||op_type == `AUIPC||op_type == `JAL||op_type == `JALR)?1:0;
            br_predict		 <= br_predict_in;
            if (inst == `END_TYPE) begin
                //todo:end
            end
                case (op_type)
                    `LUI:value[tail]       <= imm;
                    `AUIPC:value[tail]     <= imm+inst_addr;
                    `JAL,`JALR:value[tail] <= inst_addr+4;
                    default:value[tail]    <= 32'h0;
                endcase
        end
    end
    end
    
    //issue pollution
    assign rob_issue_reg   = busy[tail]&&prepared[tail]&&op_type!= `B_TYPE&&op_type!= `S_TYPE;
    assign issue_reg_id    = rd[tail];
    assign issue_rob_entry = tail;
    //COMMIT
    assign rob_commit       = busy[head]&&prepared[head]&&op_type!= `B_TYPE&&op_type!= `S_TYPE;
    assign commit_rd_reg_id = rd[head];
    assign commit_rob_entry = head;
    assign commit_value     = value[head];
    //wrong_predict
    assign clear_up = value[head][0]!= br_predict[head];
    assign next_pc  = value[head][0]?inst_addr[head]+imm[head]:inst_addr[head]+4;
    
endmodule
