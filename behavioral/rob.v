// reorder buffer and retirement unit
module rob(
  input         clk,
  input         rst,

  // common signals
  output        rob_flush,

  // brpred/rat/lsq interface
  output        rob_ret_valid,
  output [13:0] rob_ret_bptag,
  output        rob_ret_bptaken,
  output [5:0]  rob_ret_rd,
  output [31:0] rob_ret_result,
  output        rob_ret_store,
  output [4:0]  rob_ret_lsqid,

  // decode interface
  input         decode_rob_valid,
  input         decode_error,
  input [5:0]   decode_retop,
  input [13:0]  decode_bptag,
  input         decode_bptaken,
  output        rob_full,
  output [7:0]  rob_robid,

  // lsq interface
  input         lsq_rob_write,
  input [7:0]   lsq_rob_robid,
  input [4:0]   lsq_rob_lsqid,

  // csr interface
  input [31:0]  csr_tvec,
  output        rob_csr_valid,
  output [31:2] rob_csr_epc,
  output [4:0]  rob_csr_ecause,
  output [31:0] rob_csr_tval,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [4:0]   wb_ecause,
  input [7:0]   wb_robid,
  input [31:0]  wb_result);



endmodule
