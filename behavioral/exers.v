// reservation stations for execute units (scalu/mcalu)
module exers(
  input         clk,
  input         rst,

  // rename interface
  input         rename_exers_write,
  input [4:0]   rename_op,
  input [7:0]   rename_robid,
  input [5:0]   rename_rd,
  input         rename_op1ready,
  input [31:0]  rename_op1,
  input         rename_op2ready,
  input [31:0]  rename_op2,
  output        exers_stall,

  // common scalu/mcalu signals
  output [7:0]  exers_robid,
  output [5:0]  exers_rd,
  output [31:0] exers_op1,
  output [31:0] exers_op2,

  // scalu interface
  output        exers_scalu0_issue,
  output        exers_scalu1_issue,
  output [4:0]  exers_scalu_op,
  input         scalu0_stall,
  input         scalu1_stall,

  // mcalu interface
  output        exers_mcalu0_issue,
  output        exers_mcalu1_issue,
  output [4:0]  exers_mcalu_op,
  input         mcalu0_stall,
  input         mcalu1_stall,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [7:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush);

  assign exers_stall = 0;

endmodule
