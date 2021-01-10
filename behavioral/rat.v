// register allocation table (and register file)
module rat(
  input         clk,
  input         rst,

  // rename interface
  input         rename_valid,
  input [5:0]   rename_rd,
  input [7:0]   rename_robid,
  input [4:0]   rename_rs1,
  input [4:0]   rename_rs2,
  output        rat_rs1_valid,
  output [31:0] rat_rs1_tagval,
  output        rat_rs2_valid,
  output [31:0] rat_rs2_tagval,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [7:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush,
  input         rob_ret_valid,
  input [5:0]   rob_ret_rd,
  input [31:0]  rob_ret_result);



endmodule
