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

  reg [1:0]   pht [0:16383];

  reg         req_r;
  reg [13:0]  arch_bhr, spec_bhr;
  reg [13:0]  pht_rd_addr_r;
  reg [1:0]   pht_rd_data, pht_wr_data;

  wire [13:0] spec_bhr_next;
  wire [13:0] pht_rd_addr;

  // we must forward the bhr during consecutive branch predictions
  assign spec_bhr_next = {spec_bhr,brpred_bptaken};
  assign pht_rd_addr = (req_r ? spec_bhr_next : spec_bhr) ^ fetch_bp_addr[16:3];

  assign brpred_bptag = {pht_rd_data,pht_rd_addr_r};
  assign brpred_bptaken = pht_rd_data[1];

  always @(*)
    case({rob_ret_bptaken,rob_ret_bptag[15:14]})
      3'b0_00: pht_wr_data = 2'b00;
      3'b0_01: pht_wr_data = 2'b00;
      3'b0_10: pht_wr_data = 2'b01;
      3'b0_11: pht_wr_data = 2'b10;

      3'b1_00: pht_wr_data = 2'b01;
      3'b1_01: pht_wr_data = 2'b10;
      3'b1_10: pht_wr_data = 2'b11;
      3'b1_11: pht_wr_data = 2'b11;
    endcase

  // for simulation only
  integer i;
  initial
    for(i = 0; i < 16384; i=i+1)
      pht[i] = 0;

  // pht
  always @(posedge clk) begin
    if(fetch_bp_req)
      pht_rd_data <= pht[pht_rd_addr];
    if(rob_ret_branch)
      pht[rob_ret_bptag[13:0]] <= pht_wr_data;
  end

  // req_r
  always @(posedge clk)
    if(rst)
      req_r <= 0;
    else
      req_r <= fetch_bp_req;

  // arch_bhr
  always @(posedge clk)
    if(rst)
      arch_bhr <= 0;
    else if(rob_ret_branch)
      arch_bhr <= {arch_bhr,rob_ret_bptaken};

  // spec_bhr
  always @(posedge clk)
    if(rst)
      spec_bhr <= 0;
    else if(rob_flush)
      spec_bhr <= arch_bhr;
    else if(req_r)
      spec_bhr <= spec_bhr_next;

  // pht_rd_addr_r
  always @(posedge clk)
    if(fetch_bp_req)
      pht_rd_addr_r <= pht_rd_addr;

endmodule
