// single-cycle alu
module scalu(
  input         clk,
  input         rst,

  // exers interface
  input         exers_scalu_issue,
  input [4:0]   exers_scalu_op,
  input [6:0]   exers_robid,
  input [5:0]   exers_rd,
  input [31:0]  exers_op1,
  input [31:0]  exers_op2,
  output        scalu_stall,

  // wb interface
  output        scalu_valid,
  output        scalu_error,
  output [4:0]  scalu_ecause,
  output [6:0]  scalu_robid,
  output [5:0]  scalu_rd,
  output [31:0] scalu_result,
  input         wb_scalu_stall,

  // rob interface
  input         rob_flush);

  reg valid;
  reg[4:0] op;
  reg[6:0] robid;
  reg[5:0] rd;
  reg[31:0] op1;
  reg[31:0] op2;

  reg[31:0] p_vector;
  reg[4:0] p_index;

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      valid <= 1'b0;
    end
    else if (~scalu_stall) begin
      valid <= exers_scalu_issue;
      if (exers_scalu_issue) begin
        op <= exers_scalu_op;
        robid <= exers_robid;
        rd <= exers_rd;
        op1 <= exers_op1;
        op2 <= exers_op2;
      end
    end
  end

  assign scalu_stall = valid & wb_scalu_stall;
  assign scalu_valid = valid;
  assign scalu_robid = robid;
  assign scalu_rd = rd;
  assign scalu_error = 0;
  assign scalu_ecause = 0;

  alu_simple alu(
    .op(op),
    .op1(op1),
    .op2(op2),
    .sc_result(scalu_result));
  
endmodule
