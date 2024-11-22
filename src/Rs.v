`include "Const.v"
`include "Rs_chooser.v"
`include "Alu.v"

module Rs(input wire clk_in,                        // system clock signal
          input wire rst_in,                        // reset signal
          input wire rdy_in,                        // ready signal, pause cpu when low
          input wire rob_clear_up,
          input wire issue_signal,                  // from decoder
          input wire op_type_in,                    //			operation type
          input wire op_in,                         //			operation
          input wire [31:0]reg1_v_in,               //			register 1 value
          input wire [31:0]reg2_v_in,               //			register 2 value
          input wire has_dep1_in,                   //			has dependency 1
          input wire has_dep2_in,                   //			has dependency 2
          input wire [`ROB_BITS-1]rob_entry1_in,    //			rob entry 1
          input wire [`ROB_BITS-1]rob_entry2_in,    //			rob entry 2
          input wire [31:0]rd_rob_in,               //			rob entry for destination register
          input wire [31:0]inst_in,                 //			instruction
          input wire [31:0]inst_addr_in,            //			instruction address
          input wire lsb_ready,                     //from lsb
          input wire [`ROB_BIT-1:0] lsb_rob_entry,
          input wire [31:0] lsb_value,
          output wire rs_ready,                     //output
          output reg [`ROB_BIT-1:0] rs_rob_entry,
          output reg [31:0] rs_value,
          output wire is_full,
          );
    reg busy [0:`RS_SIZE-1];
    reg [6:0] op_type [0:`RS_SIZE-1];//[6:0]
    reg [2:0] op [0:`RS_SIZE-1];//[14:12]
    reg [31:0] reg1_v [0:`RS_SIZE-1];
    reg [31:0] reg2_v [0:`RS_SIZE-1];
    reg has_dep1 [0:`RS_SIZE-1];
    reg has_dep2 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rob_entry1 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rob_entry2 [0:`RS_SIZE-1];
    reg [`ROB_BITS-1:0] rd_rob [0:`RS_SIZE-1];
    reg [31:0] inst[0:`RS_SIZE-1];
    reg [31:0] inst_addr[0:`RS_SIZE-1];
    wire prepared[0:`RS_SIZE-1];
    
    generate
    genvar i;
    for (i = 0; i < `RS_SIZE; i = i + 1) begin: gen
    assign prepared[i] = busy[i]&&!has_dep1[i]&&!has_dep2[i];
    end
    endgenerate
    wire [`RS_BIT-1:0] to_exe_rs_entry;
    wire [`RS_BIT-1:0] to_issue_rs_entry;
    wire ready_to_exe;
    
    Rs_chooser Rs_chooser_inst(
    .prepared(prepared),
    .busy(busy),
    .full(is_full),
    .ready(ready_to_exe),
    .rs_entry(to_exe_rs_entry),
    .issue_entry(to_issue_rs_entry));
    
    always @(posedge clk_in) begin
        if (rst_in||rob_clear_up) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i]       <= 1'b0;
                op_type[i]    <= 7'b0;
                op[i]         <= 3'b0;
                reg1_v[i]     <= 32'b0;
                reg2_v[i]     <= 32'b0;
                has_dep1[i]   <= 1'b0;
                has_dep2[i]   <= 1'b0;
                rob_entry1[i] <= `ROB_BITS'b0;
                rob_entry2[i] <= `ROB_BITS'b0;
                rd_rob[i]     <= `ROB_BITS'b0;
                inst[i]       <= 32'b0;
                inst_addr[i]  <= 32'b0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            //listen to broadcast
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                if (busy[i]) begin
                    if (lsb_ready)begin
                        if (rob_entry1[i] == lsb_rob_entry) begin
                            reg1_v[i]   <= lsb_value;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == lsb_rob_entry) begin
                            reg2_v[i]   <= lsb_value;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                    
                    if (alu_ready) begin
                        if (rob_entry1[i] == rs_rob_entry) begin
                            reg1_v[i]   <= rs_value;
                            has_dep1[i] <= 1'b0;
                        end
                        
                        if (rob_entry2[i] == rs_rob_entry) begin
                            reg2_v[i]   <= rs_value;
                            has_dep2[i] <= 1'b0;
                        end
                    end
                end
            end
            //issue
            if (issue_signal) begin
                busy[to_issue_rs_entry]       <= 1'b1;
                op_type[to_issue_rs_entry]    <= op_type_in;
                op[to_issue_rs_entry]         <= op_in;
                reg1_v[to_issue_rs_entry]     <= reg1_v_in;
                reg2_v[to_issue_rs_entry]     <= reg2_v_in;
                has_dep1[to_issue_rs_entry]   <= has_dep1_in;
                has_dep2[to_issue_rs_entry]   <= has_dep2_in;
                rob_entry1[to_issue_rs_entry] <= rob_entry1_in;
                rob_entry2[to_issue_rs_entry] <= rob_entry2_in;
                rd_rob[to_issue_rs_entry]     <= rd_rob_in;
                inst[to_issue_rs_entry]       <= inst_in;
                inst_addr[to_issue_rs_entry]  <= inst_addr_in;
            end
            //execute
            if (ready_to_exe) begin
                busy[to_exe_rs_entry] <= 1'b0;
            end
        end
    end
    //execute
    Alu alu(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .rdy_in(rdy_in),
    .valid(ready_to_exe),
    .vi(reg1_v[to_exe_rs_entry]),
    .vj(reg2_v[to_exe_rs_entry]),
    .op(op[to_exe_rs_entry]),
    .op_type(op_type[to_exe_rs_entry]),
    .op_addition(inst[to_exe_rs_entry][30]),
    .rob_entry(rd_rob[to_exe_rs_entry]),
    .ready(rs_ready),
    .res(rs_value),
    .rob_entry_out(rs_rob_entry)
    );
    
endmodule
