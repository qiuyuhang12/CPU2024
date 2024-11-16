`include "Const.v"

//todo:read 改成瞬时
module reg(input wire clk_in,                     // system clock signal
           input wire rst_in,                     // reset signal
           input wire rdy_in,                     // ready signal, pause cpu when low
           input wire rob_clear_up,
           input wire [4:0] commit_reg_id,
           input wire [4:0] commit_reg_data,
           input wire [4:0] commit_rob_entry,
           input wire [4:0] issue_reg_id,
           input wire [4:0] issue_rob_entry,
           input wire [4:0] get_id1,
           output wire [31:0] val1,
           output wire has_dep1,
           output wire [`ROB_BIT - 1:0] dep1,
           input wire [4:0] get_id2,
           output wire [31:0] val2,
           output wire has_dep2,
           output wire [`ROB_BIT - 1:0] dep2,
           
           );
    reg [31:0] regs [0:31];
    reg dirty [0:31];
    reg [`ROB_BIT:0] rob_entry [0:31];
    assign dirty1 = dirty[get_id1];
    // if (get_id1 ! = -1) begin
    //             val1     <= regs[get_id1];
    //             has_dep1 <= dirty[get_id1];
    //             dep1     <= rob_entry[get_id1];
    //         end
            
    //         if (get_id2 ! = -1) begin
    //             val2     <= regs[get_id2];
    //             has_dep2 <= dirty[get_id2];
    //             dep2     <= rob_entry[get_id2];
    //         end
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
            if (commit_reg_id ! = 0) begin
                regs[commit_reg_id] <= commit_reg_data;
                assert dirty[commit_reg_id] == 1;
                if (rob_entry[commit_reg_id] == commit_rob_entry) begin
                    dirty[commit_reg_id]     <= 0;
                    rob_entry[commit_reg_id] <= 0;
                end
            end
            
            if (issue_reg_id ! = 0) begin
                dirty[issue_reg_id]     <= 1;
                rob_entry[issue_reg_id] <= issue_rob_entry;
            end
        end
    end
endmodule
