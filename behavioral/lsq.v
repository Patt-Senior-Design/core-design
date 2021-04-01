// load-store queue
module lsq(
  input         clk,
  input         rst,

  // rename interface
  input         rename_lsq_write,
  input [3:0]   rename_op,
  input [6:0]   rename_robid,
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
  output [31:0] lsq_dc_addr,
  output [3:0]  lsq_dc_lsqid,
  output [31:0] lsq_dc_wdata,
  output        lsq_dc_flush,
  input         dcache_lsq_ready,
  input         dcache_lsq_valid,
  input         dcache_lsq_error,
  input [3:0]   dcache_lsq_lsqid,
  input [31:0]  dcache_lsq_rdata,

  // writeback interface (out)
  output        lsq_wb_valid,
  output        lsq_wb_error,
  output [4:0]  lsq_wb_ecause,
  output [6:0]  lsq_wb_robid,
  output [5:0]  lsq_wb_rd,
  output [31:0] lsq_wb_result,
  input         wb_lsq_stall,

  // writeback interface (in)
  input         wb_valid,
  input         wb_error,
  input [6:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush,
  input         rob_ret_store);

  // load queue
  reg [15:0]  lq_valid;
  reg [15:0]  lq_base_rdy;
  reg [15:0]  lq_addr_rdy;
  reg [15:0]  lq_issued;
  reg [15:0]  lq_complete;
  reg [15:0]  lq_error;
  reg [15:0]  lq_ecause;
  reg [2:0]   lq_type [0:15];
  reg [6:0]   lq_robid [0:15];
  reg [4:0]   lq_rd [0:15];
  reg [31:0]  lq_base [0:15];
  reg [31:0]  lq_imm [0:15];
  reg [31:0]  lq_addr [0:15];
  reg [31:0]  lq_data [0:15];
  // used for lbcmp
  reg [15:0]  lq_op2_rdy;
  reg [7:0]   lq_op2 [0:15];

  // store queue
  reg [15:0]  sq_valid;
  reg [15:0]  sq_base_rdy;
  reg [15:0]  sq_addr_rdy;
  reg [15:0]  sq_data_rdy;
  reg [15:0]  sq_issue_rdy;
  reg [2:0]   sq_type [0:15];
  reg [31:0]  sq_base [0:15];
  reg [31:0]  sq_imm [0:15];
  reg [31:0]  sq_addr [0:15];
  reg [31:0]  sq_data [0:15];

  // insert at tail, retire at mid, issue/remove at head
  // when a flush occurs, sq_tail <= sq_mid
  reg [3:0]   sq_head, sq_mid, sq_tail;
  reg         sq_head_pol, sq_mid_pol, sq_tail_pol;

  wire        lq_insert_rdy;
  wire [15:0] lq_insert_sel;

  wire        lq_addrgen_req, sq_addrgen_req;
  wire [15:0] lq_addrgen_sel, sq_addrgen_sel;
  reg         lq_addrgen_req_r, sq_addrgen_req_r;
  reg [15:0]  lq_addrgen_sel_r, sq_addrgen_sel_r;
  reg [31:0]  lq_addrgen_addr, sq_addrgen_addr;

  wire        lq_issue_rdy;
  wire [15:0] lq_issue_sel, lq_sq_sel;

  wire        lq_remove_rdy;
  wire [15:0] lq_remove_sel;

  // derived signals
  wire        sq_full;
  assign sq_full = (sq_head == sq_tail) & (sq_head_pol != sq_tail_pol);

  wire        sq_insert_rdy;
  wire [15:0] sq_insert_sel;
  assign sq_insert_rdy = ~sq_full;
  assign sq_insert_sel = 1 << sq_tail;

  wire rename_beat, lq_insert_beat, sq_insert_beat;
  assign rename_beat = rename_lsq_write & ~lsq_stall;
  assign lq_insert_beat = rename_lsq_write & ~rename_op[3] & lq_insert_rdy;
  assign sq_insert_beat = rename_lsq_write & rename_op[3] & sq_insert_rdy;

  // lq_sq_wide: enables 32-byte blocks for addr comparison
  integer    i;
  reg [31:2] lq_sq_addr;
  reg        lq_sq_wide;
  reg        lq_sq_hit;
  always @(*) begin
    // generate lq_sq_addr, lq_sq_wide
    lq_sq_addr = 0;
    lq_sq_wide = 0;
    for(i = 0; i < 16; i=i+1)
      if(lq_issue_sel[i]) begin
        lq_sq_addr = lq_sq_addr | lq_addr[i][31:2];
        lq_sq_wide = lq_sq_wide | (&lq_type[i][1:0]);
      end

    // check sq entries for conflicting addresses
    lq_sq_hit = 0;
    for(i = 0; i < 16; i=i+1) begin
      if(lq_sq_sel[i] & sq_valid[i]) begin
        // any stores with unresolved address?
        if(~sq_addr_rdy[i])
          lq_sq_hit = 1;

        // any stores with conflicting address?
        if(sq_addr[i][31:5] == lq_sq_addr[31:5])
          if(lq_sq_wide | (sq_addr[i][4:2] == lq_sq_addr[4:2]))
            lq_sq_hit = 1;
      end

      // terminate loop if we found a hit
      if(lq_sq_hit)
        i = 16;
    end
  end

  wire lq_issue_req, sq_issue_req;
  assign lq_issue_req = lq_issue_rdy & ~lq_sq_hit & ~rob_flush;
  assign sq_issue_req = sq_valid[sq_head] & sq_addr_rdy[sq_head] & sq_issue_rdy[sq_head] & ~rob_flush;

  wire lq_issue_beat, sq_issue_beat;
  assign lq_issue_beat = lq_issue_req & dcache_lsq_ready;
  assign sq_issue_beat = sq_issue_req & ~lq_issue_req & dcache_lsq_ready;

  wire wb_beat;
  assign wb_beat = lsq_wb_valid & ~wb_lsq_stall;

  integer lq_insert_idx;
  always @(*)
    lq_insert_idx = $clog2(lq_insert_sel);

  integer lq_addrgen_idx;
  always @(*)
    lq_addrgen_idx = $clog2(lq_addrgen_sel_r);

  integer lq_issue_idx;
  always @(*)
    lq_issue_idx = $clog2(lq_issue_sel);

  integer lq_remove_idx;
  always @(*)
    lq_remove_idx = $clog2(lq_remove_sel);

  integer sq_addrgen_idx;
  always @(*)
    sq_addrgen_idx = $clog2(sq_addrgen_sel_r);

  // rename interface
  assign lsq_stall = ~rename_op[3] ? ~lq_insert_rdy : ~sq_insert_rdy;

  // dcache interface
  assign lsq_dc_req = lq_issue_req | sq_issue_req;
  assign lsq_dc_op = lq_issue_req ? {lq_type[lq_issue_idx],1'b0} : {sq_type[sq_head],1'b1};
  assign lsq_dc_addr = lq_issue_req ? lq_addr[lq_issue_idx] : sq_addr[sq_head];
  assign lsq_dc_lsqid = lq_issue_idx;
  assign lsq_dc_wdata = lq_issue_req ? lq_op2[lq_issue_idx] : sq_data[sq_head];
  assign lsq_dc_flush = rob_flush;

  // writeback interface (out)
  assign lsq_wb_valid = lq_remove_rdy;
  assign lsq_wb_error = lq_error[lq_remove_idx];
  assign lsq_wb_ecause = lq_ecause[lq_remove_idx];
  assign lsq_wb_robid = lq_robid[lq_remove_idx];
  assign lsq_wb_rd = lq_rd[lq_remove_idx];
  assign lsq_wb_result = lq_data[lq_remove_idx];

  priarb #(16) lq_insert_arb(
    .req(~lq_valid),
    .grant_valid(lq_insert_rdy),
    .grant(lq_insert_sel));

  priarb #(16) lq_addrgen_arb(
    .req(lq_valid & lq_base_rdy & ~lq_addr_rdy & ~lq_addrgen_sel_r),
    .grant_valid(lq_addrgen_req),
    .grant(lq_addrgen_sel));

  agemat #(16) lq_issue_arb(
    .clk(clk),
    .rst(rst),
    .insert_valid(lq_insert_beat),
    .insert_sel(lq_insert_sel),
    .req(lq_valid & lq_addr_rdy & ~lq_issued),
    .grant_valid(lq_issue_rdy),
    .grant(lq_issue_sel));

  agearr #(16,16) lq_sq_agearr(
    .clk(clk),
    .rst(rst),
    .set_row_valid(lq_insert_beat),
    .set_row_sel(lq_insert_sel),
    .clear_col_valid(sq_insert_beat),
    .clear_col_sel(sq_insert_sel),
    .row_sel(lq_issue_sel),
    .col_sel(lq_sq_sel));

  priarb #(16) lq_remove_arb(
    .req(lq_valid & lq_complete),
    .grant_valid(lq_remove_rdy),
    .grant(lq_remove_sel));

  priarb #(16) sq_addrgen_arb(
    .req(sq_valid & sq_base_rdy & ~sq_addr_rdy & ~sq_addrgen_sel_r),
    .grant_valid(sq_addrgen_req),
    .grant(sq_addrgen_sel));

  // sq_head
  always @(posedge clk)
    if(rst) begin
      sq_head <= 0;
      sq_head_pol <= 0;
    end else if(sq_issue_beat)
      {sq_head_pol,sq_head} <= {sq_head_pol,sq_head} + 1;

  // sq_mid
  always @(posedge clk)
    if(rst) begin
      sq_mid <= 0;
      sq_mid_pol <= 0;
    end else if(rob_ret_store)
      {sq_mid_pol,sq_mid} <= {sq_mid_pol,sq_mid} + 1;

  // sq_tail
  always @(posedge clk)
    if(rst) begin
      sq_tail <= 0;
      sq_tail_pol <= 0;
    end else if(rob_flush) begin
      sq_tail <= sq_mid;
      sq_tail_pol <= sq_mid_pol;
    end else if(sq_insert_beat)
      {sq_tail_pol,sq_tail} <= {sq_tail_pol,sq_tail} + 1;

  // addrgen
  always @(posedge clk)
    if(rst) begin
      lq_addrgen_req_r <= 0;
      sq_addrgen_req_r <= 0;
    end else begin
      lq_addrgen_req_r <= lq_addrgen_req;
      sq_addrgen_req_r <= sq_addrgen_req;
      lq_addrgen_sel_r <= lq_addrgen_sel;
      sq_addrgen_sel_r <= sq_addrgen_sel;
    end

  always @(*)
    lq_addrgen_addr = lq_base[lq_addrgen_idx] + lq_imm[lq_addrgen_idx];

  always @(*)
    sq_addrgen_addr = sq_base[sq_addrgen_idx] + sq_imm[sq_addrgen_idx];

  // load queue
  integer j;
  always @(posedge clk)
    if(rst | rob_flush)
      lq_valid <= 0;
    else begin
      if(lq_insert_beat) begin
        lq_valid[lq_insert_idx] <= 1;
        lq_base_rdy[lq_insert_idx] <= rename_op1ready;
        lq_addr_rdy[lq_insert_idx] <= 0;
        lq_issued[lq_insert_idx] <= 0;
        lq_complete[lq_insert_idx] <= 0;
        lq_type[lq_insert_idx] <= rename_op[2:0];
        lq_robid[lq_insert_idx] <= rename_robid;
        lq_rd[lq_insert_idx] <= rename_rd[4:0];
        lq_base[lq_insert_idx] <= rename_op1;
        lq_imm[lq_insert_idx] <= rename_imm;
        lq_op2_rdy[lq_insert_idx] <= (~&rename_op[1:0]) | rename_op2ready;
        lq_op2[lq_insert_idx] <= rename_op2[7:0];
      end

      if(lq_addrgen_req_r) begin
        lq_addr_rdy[lq_addrgen_idx] <= 1;
        lq_addr[lq_addrgen_idx] <= lq_addrgen_addr;
      end

      if(lq_issue_beat)
        lq_issued[lq_issue_idx] <= 1;

      if(dcache_lsq_valid) begin
        lq_complete[dcache_lsq_lsqid] <= 1;
        lq_error[dcache_lsq_lsqid] <= dcache_lsq_error;
        lq_ecause[dcache_lsq_lsqid] <= 0; // TODO
        lq_data[dcache_lsq_lsqid] <= dcache_lsq_rdata;
      end

      if(wb_beat)
        lq_valid[lq_remove_idx] <= 0;

      if(wb_valid & ~wb_error)
        for(j = 0; j < 16; j=j+1) begin
          if(lq_valid[j] & ~lq_base_rdy[j] & (lq_base[j][6:0] == wb_robid)) begin
            lq_base_rdy[j] <= 1;
            lq_base[j] <= wb_result;

            top.trace_lsq_base(
              {1'b0,j[3:0]},
              wb_result);
          end

          if(lq_valid[j] & ~lq_op2_rdy[j] & (lq_op2[j][6:0] == wb_robid)) begin
            lq_op2_rdy[j] <= 1;
            lq_op2[j] <= wb_result[7:0];
          end
        end
    end

  // store queue
  integer k;
  always @(posedge clk)
    if(rst)
      sq_valid <= 0;
    else if(rob_flush)
      // preserve retired but not yet issued insns
      sq_valid <= sq_valid & sq_issue_rdy;
    else begin
      if(sq_insert_beat) begin
        sq_valid[sq_tail] <= 1;
        sq_base_rdy[sq_tail] <= rename_op1ready;
        sq_addr_rdy[sq_tail] <= 0;
        sq_data_rdy[sq_tail] <= rename_op2ready;
        sq_issue_rdy[sq_tail] <= 0;
        sq_type[sq_tail] <= rename_op[2:0];
        sq_base[sq_tail] <= rename_op1;
        sq_imm[sq_tail] <= rename_imm;
        sq_data[sq_tail] <= rename_op2;
      end

      if(sq_addrgen_req_r) begin
        sq_addr_rdy[sq_addrgen_idx] <= 1;
        sq_addr[sq_addrgen_idx] <= sq_addrgen_addr;
      end

      if(rob_ret_store)
        sq_issue_rdy[sq_mid] <= 1;

      if(sq_issue_beat)
        sq_valid[sq_head] <= 0;

      if(wb_valid & ~wb_error)
        for(k = 0; k < 16; k=k+1)
          if(sq_valid[k]) begin
            if(~sq_base_rdy[k] & (sq_base[k][6:0] == wb_robid)) begin
              sq_base_rdy[k] <= 1;
              sq_base[k] <= wb_result;

              top.trace_lsq_base(
                {1'b1,k[3:0]},
                wb_result);
            end

            if(~sq_data_rdy[k] & (sq_data[k][6:0] == wb_robid)) begin
              sq_data_rdy[k] <= 1;
              sq_data[k] <= wb_result;

              top.trace_lsq_wdata(
                {1'b1,k[3:0]},
                wb_result);
            end
          end
    end

  always @(posedge clk)
    if(rename_beat)
      top.trace_lsq_dispatch(
        rename_robid,
        rename_op[3] ? {1'b1,sq_tail} : {1'b0,lq_insert_idx},
        rename_op,
        rename_op1,
        rename_op2);

  always @(posedge clk)
    if(~rst)
      top.log_lsq_inflight(
        lq_valid,
        sq_valid);

endmodule
