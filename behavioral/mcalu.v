// multi-cycle alu
module mcalu(
  input         clk,
  input         rst,

  // exers interface
  input         exers_mcalu_issue,
  input [4:0]   exers_mcalu_op,
  input [7:0]   exers_robid,
  input [5:0]   exers_rd,
  input [31:0]  exers_op1,
  input [31:0]  exers_op2,
  output        mcalu_stall,

  // wb interface
  output        mcalu_valid,
  output        mcalu_error,
  output [4:0]  mcalu_ecause,
  output [7:0]  mcalu_robid,
  output [5:0]  mcalu_rd,
  output [31:0] mcalu_result,
  input         wb_mcalu_stall,

  // rob interface
  input         rob_flush);

  assign mcalu_valid = 0;

endmodule
