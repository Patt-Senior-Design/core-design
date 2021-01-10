// single-cycle alu
module scalu(
  input         clk,
  input         rst,

  // exers interface
  input         exers_scalu_issue,
  input [4:0]   exers_scalu_op,
  input [7:0]   exers_robid,
  input [5:0]   exers_rd,
  input [31:0]  exers_op1,
  input [31:0]  exers_op2,
  output        scalu_stall,

  // wb interface
  output        scalu_valid,
  output        scalu_error,
  output [4:0]  scalu_ecause,
  output [7:0]  scalu_robid,
  output [5:0]  scalu_rd,
  output [31:0] scalu_result,
  input         wb_scalu_stall,

  // rob interface
  input         rob_flush);



endmodule
