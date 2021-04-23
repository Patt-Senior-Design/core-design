// two-level adaptive branch predictor
module brpred(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_bp_req,
  input [31:2]  fetch_bp_addr,
  output [15:0] brpred_bptag,
  output        brpred_bptaken,

  // rob interface
  input         rob_flush,
  input         rob_ret_branch,
  input [15:0]  rob_ret_bptag,
  input         rob_ret_bptaken);

  wire [1:0]   pht [0:16383];

  wire         req_r;
  wire [13:0]  arch_bhr, spec_bhr;
  wire [13:0]  pht_rd_addr_r;
  wire [1:0]   pht_rd_data;
  wire [1:0]   pht_wr_data;

  wire [13:0] arch_bhr_next, spec_bhr_next;
  wire [13:0] pht_rd_addr;

  assign arch_bhr_next = {arch_bhr[12:0],rob_ret_bptaken};
  assign spec_bhr_next = {spec_bhr[12:0],brpred_bptaken};

  // we must forward the bhr during consecutive branch predictions
  assign pht_rd_addr = (req_r ? spec_bhr_next : spec_bhr) ^ fetch_bp_addr[16:3];

  assign brpred_bptag = {pht_rd_data,pht_rd_addr_r};
  assign brpred_bptaken = pht_rd_data[1];

  // pht_wr_data
  assign pht_wr_data[1] = (rob_ret_bptaken & (|rob_ret_bptag[15:14])) | (&rob_ret_bptag[15:14]);
  assign pht_wr_data[0] = (~rob_ret_bptag[14] & (rob_ret_bptag[15] | rob_ret_bptaken)) | 
    (&{rob_ret_bptaken, rob_ret_bptag[15:14]});
 
  // ==
  // for simulation: sram reset initial
  sram #(2, 14) pht_ram (.clk(clk), .rst(rst), .ren(fetch_bp_req), .raddr(pht_rd_addr),
    .rdata(pht_rd_data), .wen(rob_ret_branch), .waddr(rob_ret_bptag[13:0]), .wdata(pht_wr_data));
  // ==

  // req_r
  flop req_r_flop (.clk(clk), .rst(rst|~fetch_bp_req), .set(~rst&fetch_bp_req), .enable(1'b0), .d(1'b0), .q(req_r));

  // arch_bhr
  flop #(14) arch_bhr_flop (.clk(clk), .rst(rst), .set(1'b0), .enable(rob_ret_branch), .d(arch_bhr_next), .q(arch_bhr));

  // spec_bhr
  wire [13:0] spec_bhr_in;
  wire [13:0] spec_bhr_flush;
  mux #(14, 2) spec_bhr_flush_mux (.sel(rob_ret_branch), .in({arch_bhr_next, arch_bhr}),
      .out(spec_bhr_flush));
  mux #(14, 2) spec_bhr_in_mux (.sel(rob_flush),
      .in({spec_bhr_flush, spec_bhr_next}), .out(spec_bhr_in));

  wire spec_bhr_en = rob_flush | req_r;
  flop #(14) spec_bhr_flop (.clk(clk), .rst(rst), .set(1'b0), .enable(spec_bhr_en),
      .d(spec_bhr_in), .q(spec_bhr));

  // pht_rd_addr_r
  flop #(14) pht_rd_addr_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), 
      .enable(fetch_bp_req), .d(pht_rd_addr), .q(pht_rd_addr_r));

endmodule
