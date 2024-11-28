/*`include "/run/media/grace/archlinux_data/verilog_file/CPU2024/src/Const.v" */
`include "Const.v"

module Decoder (input wire clk_in,                    // system clock signal
                input wire rst_in,                    // reset signal
                input wire rdy_in,                    // ready signal, pause cpu when low
                input wire wrong_predicted,           // from rob
                input wire [31:0] correct_pc,
                output wire [31:0] next_pc,           // to inst fetcher
                output wire jalr_stall,
                input wire [31:0] inst_addr,
                input wire [31:0] inst,
                input wire start_decode,              // start decoder
                output wire br_predict,               // to rob
                output wire issue_signal,             // to rob inst_fetcher
                output wire issue_signal_rs,          // to rs
                output wire issue_signal_lsb,         // to lsb
                output wire [31:0] imm,               //			经过sext/直接issue/br的offset
                output wire [6:0] op_type,            //			operation type
                output wire [2:0] op,                 //			operation
                output wire [31:0]reg1_v,             //			register 1 value
                output wire [31:0]reg2_v,             //			register 2 value
                output wire has_dep1,                 //			has dependency 1
                output wire has_dep2,                 //			has dependency 2
                output wire [`ROB_BIT-1:0]rob_entry1, //			rob entry 1
                output wire [`ROB_BIT-1:0]rob_entry2, //			rob entry 2
                output wire [4:0]rd_id,               //			destination register
                output wire [`ROB_BIT-1:0]rd_rob,     //			rob entry for destination register
                output wire [31:0]inst_out,           //			instruction
                output wire [31:0]inst_addr_out,      //			instruction address
                input wire rob_full,                  // from rob
                input wire [`ROB_BIT-1:0] rob_tail,
                input wire rs_full,                   // from rs
                input wire lsb_full,                  // from lsb
                output wire [4:0] get_id1,            // between reg and decoder
                input wire [31:0] val1,
                input wire has_dep1_,                 //			has dependency 1
                input wire [`ROB_BIT - 1:0] dep1,
                output wire [4:0] get_id2,
                input wire [31:0] val2,
                input wire has_dep2_,                 //			has dependency 2
                input wire [`ROB_BIT - 1:0] dep2);
    
    assign br_predict       = op_type == `B_TYPE;
    assign issue_signal     = start_decode&&!wrong_predicted&&!jalr_stall&& !rob_full && !rs_full && !lsb_full;
    assign issue_signal_rs  = issue_signal&&(op_type == `ALGI_TYPE || op_type == `R_TYPE||op_type == `B_TYPE);
    assign issue_signal_lsb = issue_signal&&(op_type == `LD_TYPE || op_type == `S_TYPE);
    wire no_rs2;
    assign no_rs2 = op_type == `LUI || op_type == `AUIPC || op_type == `JAL || op_type == `JALR || op_type == `LD_TYPE || op_type == `ALGI_TYPE;
    // wire no_rd;
    // assign no_rd         = op_type == `B_TYPE||op_type == `S_TYPE;
    // assign op_type    = inst[6:0];
    // assign op         = inst[14:12];
    // assign get_id1    = inst[19:15];
    // assign get_id2    = inst[24:20];
    assign reg1_v        = val1;
    assign reg2_v        = no_rs2 ? imm : val2;
    assign has_dep1      = has_dep1_;
    assign has_dep2      = no_rs2 ? 0 : has_dep2_;
    assign rob_entry1    = dep1;
    assign rob_entry2    = no_rs2 ? 0 : dep2;
    // assign rd_id      = no_rd?0:inst[11:7];
    assign rd_rob        = rob_tail;
    assign inst_addr_out = inst_addr;
    assign inst_out      = inst;
    assign jalr_stall    = inst[6:0] == `JALR && has_dep1_;
    wire [31:0]pc_predictor_next_pc;
    CPc_predictor CPc_predictor_inst(
    .now_pc(inst_addr),
    .now_inst(inst),
    .val1(val1),
    .op_type(op_type),
    .imm(imm),
    .next_pc(pc_predictor_next_pc));
    assign next_pc = wrong_predicted ? correct_pc : pc_predictor_next_pc;
    
    assign op_type = get_op_type(inst);
    function [6:0]get_op_type;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b000: get_op_type = `ALGI_TYPE;
                3'b010: get_op_type = `LD_TYPE;
                3'b110: get_op_type = `S_TYPE;
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_op_type = `ALGI_TYPE;
                    3'b001: get_op_type = `JAL;
                    3'b010: get_op_type = `ALGI_TYPE;
                    3'b011: begin
                        if (inst[11:7] == 2)get_op_type   = `ALGI_TYPE;
                        else get_op_type = `LUI;
                    end
                    3'b100: case (inst[11:10])
                        2'b11:get_op_type = `R_TYPE; 
                        default: get_op_type = `ALGI_TYPE;
                    endcase
                    3'b101: get_op_type = `JAL;
                    3'b110: get_op_type = `B_TYPE;
                    3'b111: get_op_type = `B_TYPE;
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_op_type = `ALGI_TYPE;
                    3'b010: get_op_type = `LD_TYPE;
                    3'b100: case (inst[12])
                        1'b0:case (inst[6:2])
                            1'b0: get_op_type = `JALR;
                            1'b1: get_op_type = `R_TYPE;
                        endcase
                        1'b1:case (inst[6:2])
                            1'b0: get_op_type = `JALR;
                            1'b1: get_op_type = `R_TYPE;
                        endcase
                    endcase
                    3'b110: get_op_type = `S_TYPE;
                endcase
            end
        endcase
    endfunction
    
    //todo:op_addition!!!!!!!!!!
    localparam Add= 3'b000,Sub = 3'b000, Sll = 3'b001, Slt = 3'b010, Sltu = 3'b011, Xor = 3'b100, Srl= 3'b101,Sra = 3'b101, Or = 3'b110, And = 3'b111;
    localparam Beq = 3'b000, Bne = 3'b001, Blt = 3'b100, Bge = 3'b101, Bltu = 3'b110, Bgeu = 3'b111;
    localparam Lb=3'b000, Lh=3'b001, Lw=3'b010, Lbu=3'b100, Lhu=3'b101;
    localparam Sb=3'b000, Sh=3'b001, Sw=3'b010;
    assign op = get_op(inst);
    function [2:0]get_op;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b000: get_op = Add;
                3'b010: get_op = Lw;
                3'b110: get_op = Sw;
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_op = Add;
                    3'b001: get_op = 3'b000;
                    3'b010: get_op = Add;
                    3'b011: begin
                        if (inst[11:7] == 2)get_op = Add;
                        else get_op = 3'b000;
                    end
                    3'b100: case (inst[11:10])
                        2'b00:get_op = Srl;
                        2'b01:get_op = Sra;
                        2'b10:get_op = And;
                        2'b11:case (inst[6:5])
                            2'b00: get_op = Sub;
                            2'b01: get_op = Xor;
                            2'b10: get_op = Or;
                            2'b11: get_op = And;
                        endcase
                    endcase
                    3'b101: get_op = 3'b000;
                    3'b110: get_op = Beq;
                    3'b111: get_op = Bne;
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_op = Sll;
                    3'b010: get_op = Lw;
                    3'b100: case (inst[12])
                        1'b0:case (inst[6:2])
                            1'b0: get_op = 3'b000;
                            1'b1: get_op = Add;
                        endcase
                        1'b1:case (inst[6:2])
                            1'b0: get_op = 3'b000;
                            1'b1: get_op = Add;
                        endcase
                    endcase
                    3'b110: get_op = Sw;
                endcase
            end
        endcase
    endfunction
    
    assign get_id1 = get_get_id1(inst);
    function [4:0]get_get_id1;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b000: get_get_id1 = 2;
                default: get_get_id1 = 8+inst[9:7];
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000: get_get_id1 = inst[11:7];
                    3'b001: get_get_id1 = 0;
                    3'b010: get_get_id1 = 0;
                    3'b011: begin
                        if (inst[11:7] == 2)get_get_id1 = 2;
                        else get_get_id1 = 0;
                    end
                    3'b100,3'b110,3'b111: get_get_id1 = 8+inst[9:7];
                    3'b101: get_get_id1 = 0;
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_get_id1 = inst[11:7];
                    3'b010: get_get_id1 = 2;
                    3'b100: case (inst[12])
                        1'b0:case (inst[6:2])
                            1'b0: get_get_id1 = inst[11:7];
                            1'b1: get_get_id1 = 0;
                        endcase
                        1'b1:get_get_id1 = inst[11:7];
                    endcase
                    3'b110: get_get_id1 = 2;
                endcase
            end
        endcase
    endfunction

    assign get_id2 = get_get_id2(inst);
    function [4:0]get_get_id2;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b110: get_get_id2 = 8+inst[4:2];
                default: get_get_id2 = 0;
            endcase
            2'b01: begin
                if (inst[15:13]==3'b100&&inst[11:10]==2'b11)get_get_id2 = 8+inst[4:2];
                else get_get_id2 = 0;
            end
            2'b10: begin
                case (inst[15:13])
                    3'b100: get_get_id2 = inst[6:2];
                    default: get_get_id2 = 0;
                endcase
            end
        endcase
    endfunction
    
    //todo:c.j，c.jr不issue (maybe rd=0&&!store inst?)
    assign rd_id = get_rd_id(inst);
    function [4:0]get_rd_id;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
                3'b110: get_rd_id = 0;
                default: get_rd_id = 8+inst[4:2];
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000,3'b010,3'b011: get_rd_id = inst[11:7];
                    3'b001: get_rd_id = 1;
                    3'b100: get_rd_id = 8+inst[9:7];
                    3'b101,3'b110,3'b111: get_rd_id = 0;
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000,3'b010: get_rd_id = inst[11:7];
                    3'b100: case (inst[12])
                        1'b0:case (inst[6:2])
                            1'b0: get_rd_id = 0;
                            1'b1: get_rd_id = inst[11:7];
                        endcase
                        1'b1:case (inst[6:2])
                            1'b0: get_rd_id = 1;
                            1'b1: get_rd_id = inst[11:7];
                        endcase
                    endcase
                    3'b110: get_rd_id = 0;
                endcase
            end
        endcase
    endfunction
    
    assign imm = get_imm(inst);
    function [31:0]get_imm;
        input [31:0] inst;
        case (inst[1:0])
            2'b00: case (inst[15:13])
            //uimm[5:4|9:6|2|3]
                3'b000: get_imm = {22'b0,inst[10:7],inst[12:11],inst[5],inst[6],2'b0};
                default: get_imm = {24'b0,inst[5],inst[12:10],inst[6],2'b0};
            endcase
            2'b01: begin
                case (inst[15:13])
                    3'b000,3'b010: get_imm = {{27{inst[12]}},inst[6:2]};
                    3'b001,3'b101: get_imm = {{21{inst[12]}},inst[8],inst[10:9],inst[6],inst[7],inst[2],inst[11],inst[5:3],1'b0};
                    3'b011: begin
                        if (inst[11:7] == 2)get_imm = {{23{inst[12]}},inst[4:3],inst[5],inst[2],inst[6],4'b0};
                        else get_imm = {{15{inst[17]}},inst[6:2],12'b0};
                    end
                    3'b100: case (inst[11:10])
                        2'b00,2'b01:get_imm = {26'b0,inst[12],inst[6:2]};
                        2'b10:get_imm = {{27{inst[12]}},inst[6:2]};
                        2'b11:get_imm = 0;
                    endcase
                    3'b110,3'b111: get_imm = {{24{inst[12]}},inst[6:5],inst[2],inst[11:10],inst[4:3],1'b0};
                endcase
            end
            2'b10: begin
                case (inst[15:13])
                    3'b000: get_imm = {26'b0,inst[12],inst[6:2]};
                    3'b010: get_imm = {24'b0,inst[3:2],inst[12],inst[6:4],2'b0};
                    3'b100: get_imm = 0;
                    3'b110: get_imm = {24'b0,inst[8:7],inst[12:9],2'b0};
                endcase
            end
        endcase
    endfunction
endmodule
