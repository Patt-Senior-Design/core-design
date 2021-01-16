// load-store queue
module lsq(
  input         clk,
  input         rst,

  // rename interface
  input         rename_lsq_write,
  input [3:0]   rename_op,
  input [7:0]   rename_robid,
  input [5:0]   rename_rd,
  input         rename_op1ready,
  input [31:0]  rename_op1,
  input         rename_op2ready,
  input [31:0]  rename_op2,
  input [31:0]  rename_imm,
  output        lsq_stall,

  // dcache interface
  output        lsq_dc_req,
  output [3:0]  lsq_dc_op,
  output [4:0]  lsq_dc_lsqid,
  output [31:0] lsq_dc_wdata,
  output        lsq_dc_flush,
  input         dcache_ready,
  input         dcache_valid,
  input         dcache_error,
  input [4:0]   dcache_lsqid,
  input [31:0]  dcache_rdata,

  // writeback interface (out)
  output        lsq_wb_valid,
  output        lsq_wb_error,
  output [4:0]  lsq_wb_ecause,
  output [7:0]  lsq_wb_robid,
  output [5:0]  lsq_wb_rd,
  output [31:0] lsq_wb_result,
  input         wb_lsq_stall,

  // writeback interface (in)
  input         wb_valid,
  input         wb_error,
  input [7:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  output        lsq_rob_write,
  output [6:0]  lsq_rob_robid,
  output [4:0]  lsq_rob_lsqid,
  input         rob_flush,
  input         rob_ret_store,
  input [4:0]   rob_ret_lsqid);

  assign lsq_stall = 0;
  assign lsq_rob_write = 0;

endmodule
