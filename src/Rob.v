`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v"

module Rob(input wire clk_in,                           // system clock signal
           input wire rst_in,                           // reset signal
           input wire rdy_in,                           // ready signal, pause cpu when low
           output wire rob_full,
           output wire rob_empty,
           output wire [`ROB_BIT-1:0]rob_head,
           output wire [`ROB_BIT-1:0]rob_tail,
           output wire clear_up,                        // wrong_predicted
           output wire [31:0] next_pc,
           input wire issue_signal,                     // from decoder
           input wire [31:0] inst_addr,
           input wire [31:0] inst,
           input wire [`REG_BIT - 1:0] rd_id,
           input wire [31:0] imm_in,                    //					经过sext/直接issue/br的offset
           input wire br_predict_in,                    //					1 jump, 0 not jump
           input wire [6:0]op_type,                     //					大
           input wire [2:0]op,                          //					小
           output wire issue_pollute,                   // to reg			/issue 			to reg//defualt 0
           output wire [4:0] issue_reg_id,              // 			/issue 			to reg//defualt 0
           output wire [`ROB_BIT-1:0] issue_rob_entry,
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
           output wire [31:0] value1,
           input wire [`ROB_BIT-1:0] get_rob_entry2,
           output wire ready2,
           output wire [31:0] value2);
    //todo:广播不一定对齐了
    reg [`ROB_BIT-1:0] head;
    reg [`ROB_BIT-1:0] tail;
    reg busy[0:`ROB_SIZE-1];
    reg prepared[0:`ROB_SIZE-1];
    reg [31:0] insts[0:`ROB_SIZE-1];
    reg [31:0] insts_addr[0:`ROB_SIZE-1];
    reg [4:0] rd[0:`ROB_SIZE-1];
    reg [31:0] value[0:`ROB_SIZE-1];//value->rd | br is true
    reg br_predict[0:`ROB_SIZE-1];
    reg [31:0] imm[0:`ROB_SIZE-1];
    reg [6:0] op_type_save[0:`ROB_SIZE-1];
    integer i;
    assign rob_head             = head;
    assign rob_tail             = tail;
    assign rob_empty            = (head == tail) && !busy[head];
    // assign rob_full          = ((tail == head) && busy[tail]) || ((tail + 1 == head) && busy[tail - 1] && issue_signal);
    // assign rob_full          = (((tail + 1)&((1<<`ROB_BIT)-1)) == head) || (((tail + 2)&((1<<`ROB_BIT)-1) == head) && issue_signal);
    // assign rob_full          = (tail + 1)%`ROB_SIZE == head || (((2+tail)%`ROB_SIZE == head) && issue_signal);
    parameter [`ROB_BIT-1:0]tmp = (`ROB_BIT'b1<<`ROB_BIT)-1;
    assign rob_full             = ((tail + 1-head)&tmp) == 0;
    // assign rob_full          = 1;
    wire issue_val_ready=issue_signal&&(op_type == `LUI || op_type == `AUIPC || op_type == `JAL || op_type == `JALR);
    wire issue_val=calculate_value(op_type, imm_in, inst_addr);
    assign ready1 = prepared[get_rob_entry1] || (rs_ready_bd && rs_rob_entry == get_rob_entry1) || (lsb_ready_bd && lsb_rob_entry == get_rob_entry1)||(issue_signal && tail == get_rob_entry1&&issue_val_ready);
    assign value1 = prepared[get_rob_entry1] ? value[get_rob_entry1]:((rs_ready_bd && rs_rob_entry == get_rob_entry1)?rs_value:((lsb_ready_bd && lsb_rob_entry == get_rob_entry1)?lsb_value:issue_val));
    assign ready2 = prepared[get_rob_entry2] || (rs_ready_bd && rs_rob_entry == get_rob_entry2) || (lsb_ready_bd && lsb_rob_entry == get_rob_entry2)||(issue_signal && tail == get_rob_entry2&&issue_val_ready);
    assign value2 = prepared[get_rob_entry2] ? value[get_rob_entry2]:((rs_ready_bd && rs_rob_entry == get_rob_entry2)?rs_value:((lsb_ready_bd && lsb_rob_entry == get_rob_entry2)?lsb_value:issue_val));
    always @(posedge clk_in)
    begin
        if (rst_in || (clear_up && rdy_in)) begin
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                busy[i]         <= 1'b0;
                prepared[i]     <= 1'b0;
                insts[i]        <= 32'h0;
                insts_addr[i]   <= 32'h0;
                rd[i]           <= 5'h0;
                value[i]        <= 32'h0;
                br_predict[i]   <= 1'b0;
                imm[i]          <= 32'h0;
                op_type_save[i] <= 7'h0;
            end
            head <= 0;
            tail <= 0;
            end else if (!rdy_in) begin
            // do nothing
            end else begin
            // RECEIVE BROADCAST
            if (rs_ready_bd) begin
                if (!(busy[rs_rob_entry] && !prepared[rs_rob_entry])) begin
                    $fatal(1,"Assertion failed: wild rs_rob_entry");
                end
                
                if (rd[rs_rob_entry]) begin
                    value[rs_rob_entry] <= rs_value;
                end
                prepared[rs_rob_entry] <= 1;
            end
            
            if (lsb_ready_bd) begin
                if (!(busy[lsb_rob_entry] && !prepared[lsb_rob_entry])) begin
                    $fatal(1,"Assertion failed: wild lsb_rob_entry");
                end
                
                if (rd[rs_rob_entry]) begin
                    value[lsb_rob_entry] <= lsb_value;
                end
                prepared[lsb_rob_entry] <= 1;
            end
            
            //COMMIT
            if (busy[head] && prepared[head]) begin
                head               <= head+1;
                busy[head]         <= 1'b0;
                prepared[head]     <= 1'b0;
                insts[head]        <= 32'h0;
                insts_addr[head]   <= 32'h0;
                rd[head]           <= 5'b0;
                value[head]        <= 32'h0;
                br_predict[head]   <= 1'b0;
                imm[head]          <= 32'h0;
                op_type_save[head] <= 7'h0;
            end
            
            //ISSUE
            if (issue_signal) begin
                //prepare、value、branch
                tail             <= tail+1;
                busy[tail]       <= 1'b1;
                insts[tail]      <= inst;
                insts_addr[tail] <= inst_addr;
                prepared[tail]     <= (op_type == `LUI || op_type == `AUIPC || op_type == `JAL || op_type == `JALR)?1'b1:1'b0;
                br_predict[tail]   <= br_predict_in;
                imm[tail]          <= imm_in;
                op_type_save[tail] <= op_type;
                rd[tail]           <= rd_id;
                value[tail] <= calculate_value(op_type, imm_in, inst_addr);
                // case (op_type)
                //     `LUI:value[tail]       <= imm_in;
                //     `AUIPC:value[tail]     <= imm_in+inst_addr;
                //     `JAL,`JALR:value[tail] <= inst_addr+4;
                //     default:value[tail]    <= 32'h0;
                // endcase
            end
        end
    end
    
    function [31:0] calculate_value;
        input [6:0] op_type;
        input [31:0] imm_in;
        input [31:0] inst_addr;
        begin
            case (op_type)
                `LUI: calculate_value        = imm_in;
                `AUIPC: calculate_value      = imm_in + inst_addr;
                `JAL, `JALR: calculate_value = inst_addr + 4;
                default: calculate_value     = 32'h0;
            endcase
        end
    endfunction
    
    //issue pollution
    assign issue_pollute   = issue_signal && op_type!= `B_TYPE && op_type!= `S_TYPE;
    assign issue_reg_id    = rd_id;
    assign issue_rob_entry = tail;
    //COMMIT
    assign rob_commit       = busy[head] && prepared[head] && op_type!= `B_TYPE && op_type!= `S_TYPE;
    assign commit_rd_reg_id = rd[head];
    assign commit_rob_entry = head;
    assign commit_value     = value[head];
    //wrong_predict
    assign clear_up = op_type_save[head]==`B_TYPE&&value[head][0]!= br_predict[head];
    assign next_pc  = clear_up?value[head][0]?insts_addr[head]+imm[head]:insts_addr[head]+32'h4:0;
    
endmodule
