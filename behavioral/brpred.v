// two-level adaptive branch predictor
module brpred(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_bp_req,
  input [31:2]  fetch_bp_addr,
  output        brpred_bptaken,
  output [13:0] brpred_bptag,
  output [31:2] brpred_addr,

  // rob interface
  input         rob_flush,
  input         rob_ret_valid,
  input         rob_ret_brtaken,
  input [13:0]  rob_ret_brtag);

endmodule
