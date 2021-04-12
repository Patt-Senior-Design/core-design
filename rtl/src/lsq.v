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
  wire [15:0]        lq_valid;
  wire [15:0]        lq_base_rdy;
  wire [15:0]        lq_addr_rdy;
  wire [15:0]        lq_issued;
  wire [15:0]        lq_complete;
  wire [15:0]        lq_error;
  wire [(5*16)-1:0]  lq_ecause;
  wire [(3*16)-1:0]  lq_type;
  wire [(7*16)-1:0]  lq_robid;
  wire [(5*16)-1:0]  lq_rd;
  wire [(32*16)-1:0] lq_base;
  wire [(32*16)-1:0] lq_imm;
  wire [(32*16)-1:0] lq_addr;
  wire [(32*16)-1:0] lq_data;
  wire [15:0]        lq_op2_rdy;
  wire [(8*16)-1:0]  lq_op2;

  wire        lq_insert_rdy;
  wire [15:0] lq_insert_sel;

  // addrgen combinational input
  wire        lq_addrgen_req_in;
  wire [15:0] lq_addrgen_sel_in;
  // addrgen registered output
  wire        lq_addrgen_req;
  wire [15:0] lq_addrgen_sel;
  // addrgen combinational output
  wire [31:0] lq_addrgen_addr;

  wire        lq_issue_rdy;
  wire [15:0] lq_issue_sel, lq_sq_sel;

  wire        lq_remove_rdy;
  wire [15:0] lq_remove_sel;

  wire        lq_sq_hit;

  // store queue
  wire [15:0]        sq_valid;
  wire [15:0]        sq_base_rdy;
  wire [15:0]        sq_addr_rdy;
  wire [15:0]        sq_data_rdy;
  wire [15:0]        sq_issue_rdy;
  wire [(3*16)-1:0]  sq_type;
  wire [(32*16)-1:0] sq_base;
  wire [(32*16)-1:0] sq_imm;
  wire [(32*16)-1:0] sq_addr;
  wire [(32*16)-1:0] sq_data;

  // one-hot counters
  // insert at tail, retire at mid, issue/remove at head
  // when a flush occurs, sq_tail <= sq_mid
  wire [15:0] sq_head, sq_mid, sq_tail;
  wire        sq_head_pol, sq_mid_pol, sq_tail_pol;

  // addrgen combinational input
  wire        sq_addrgen_req_in;
  wire [15:0] sq_addrgen_sel_in;
  // addrgen registered output
  wire        sq_addrgen_req;
  wire [15:0] sq_addrgen_sel;
  // addrgen combinational output
  wire [31:0] sq_addrgen_addr;

  // derived signals
  wire rst_flush = rst | rob_flush;

  wire sq_full = (|(sq_head & sq_tail)) & (sq_head_pol ^ sq_tail_pol);

  wire wb_en = wb_valid & ~wb_error;
  wire wb_beat = lsq_wb_valid & ~wb_lsq_stall;
  genvar i;

  // rename interface
  mux #(1,2) lsq_stall_mux(
    .sel(rename_op[3]),
    .in({sq_full,~lq_insert_rdy}),
    .out(lsq_stall));

  // dcache interface
  wire [2:0] lq_type_out, sq_type_out;
  premux #(3,16) lq_type_out_mux(lq_issue_sel, lq_type, lq_type_out);
  premux #(3,16) sq_type_out_mux(sq_head, sq_type, sq_type_out);

  wire [31:0] lq_addr_out, sq_addr_out;
  premux #(32,16) lq_addr_out_mux(lq_issue_sel, lq_addr, lq_addr_out);
  premux #(32,16) sq_addr_out_mux(sq_head, sq_addr, sq_addr_out);

  wire [7:0] lq_op2_out;
  wire [31:0] sq_data_out;
  premux #(8,16) lq_data_out_mux(lq_issue_sel, lq_op2, lq_op2_out);
  premux #(32,16) sq_data_out_mux(sq_head, sq_data, sq_data_out);

  assign lsq_dc_req = lq_issue_req | |sq_issue_req;
  mux #(3,2) dc_op_mux(lq_issue_req, {lq_type_out,sq_type_out}, lsq_dc_op[3:1]);
  assign lsq_dc_op[0] = ~lq_issue_req;
  mux #(32,2) dc_addr_mux(lq_issue_req, {lq_addr_out,sq_addr_out}, lsq_dc_addr);
  encoder #(16) dc_lsqid_encoder(
    .in(lq_issue_sel),
    .invalid(),
    .out(lsq_dc_lsqid));
  mux #(32,2) dc_wdata_mux(lq_issue_req, {24'b0,lq_op2_out,sq_data_out}, lsq_dc_wdata);
  assign lsq_dc_flush = rob_flush;

  // writeback interface (out)
  assign lsq_wb_valid = lq_remove_rdy;
  premux #(1,16) lq_error_mux(lq_remove_sel, lq_error, lsq_wb_error);
  premux #(5,16) lq_ecause_mux(lq_remove_sel, lq_ecause, lsq_wb_ecause);
  premux #(7,16) lq_robid_mux(lq_remove_sel, lq_robid, lsq_wb_robid);
  premux #(5,16) lq_rd_mux(lq_remove_sel, lq_rd, lsq_wb_rd[4:0]);
  assign lsq_wb_rd[5] = 0;
  premux #(32,16) lq_data_mux(lq_remove_sel, lq_data, lsq_wb_result);

  // ------------------------------------------------------------------load queue
  wire        lq_insert_beat = rename_lsq_write & ~rename_op[3] & lq_insert_rdy;
  wire [15:0] lq_insert_en = {16{lq_insert_beat}} & lq_insert_sel;

  wire        lq_issue_req = lq_issue_rdy & ~lq_sq_hit & ~rob_flush;
  wire        lq_issue_beat = lq_issue_req & dcache_lsq_ready;

  wire [15:0] lq_remove_en = {16{wb_beat}} & lq_remove_sel;

  priarb #(16) lq_insert_arb(
    .req(~lq_valid),
    .grant_valid(lq_insert_rdy),
    .grant(lq_insert_sel));

  priarb #(16) lq_remove_arb(
    .req(lq_valid & lq_complete),
    .grant_valid(lq_remove_rdy),
    .grant(lq_remove_sel));

  // lq_addrgen
  wire        lq_addrgen_req_in, lq_addrgen_req;
  wire [15:0] lq_addrgen_sel_in, lq_addrgen_sel;

  priarb #(16) lq_addrgen_arb(
    .req(lq_valid & lq_base_rdy & ~lq_addr_rdy & ~lq_addrgen_sel),
    .grant_valid(lq_addrgen_req_in),
    .grant(lq_addrgen_sel_in));

  flop lq_addrgen_req_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(1'b1),
    .d(lq_addrgen_req_in),
    .q(lq_addrgen_req));

  flop #(16) lq_addrgen_sel_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(1'b1),
    .d(lq_addrgen_sel_in),
    .q(lq_addrgen_sel));

  wire [31:0] lq_addrgen_base, lq_addrgen_imm;
  premux #(32,16) lq_addrgen_base_mux(
    .sel(lq_addrgen_sel),
    .in(lq_base),
    .out(lq_addrgen_base));
  premux #(32,16) lq_addrgen_imm_mux(
    .sel(lq_addrgen_sel),
    .in(lq_imm),
    .out(lq_addrgen_imm));

  wire [31:0] lq_addrgen_addr;
  rca #(32) lq_addrgen_addr_adder(
    .sub(1'b0),
    .a(lq_addrgen_base),
    .b(lq_addrgen_imm),
    .c(lq_addrgen_addr));

  // lq_valid
  flop lq_valid_r[15:0](
    .clk(clk),
    .rst({16{rst_flush}} | lq_remove_en),
    .set(lq_insert_en),
    .enable(1'b0),
    .d(1'b0),
    .q(lq_valid));

  // lq_type, lq_robid, lq_rd, lq_imm
  flop #(3) lq_type_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en),
    .d(rename_op[2:0]),
    .q(lq_type));

  flop #(7) lq_robid_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en),
    .d(rename_robid),
    .q(lq_robid));

  flop #(5) lq_rd_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en),
    .d(rename_rd[4:0]),
    .q(lq_rd));

  flop #(32) lq_imm_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en),
    .d(rename_imm),
    .q(lq_imm));

  // lq_base
  wire [(32*16)-1:0] lq_base_next;

  wire [15:0] lq_base_cmp;
  generate
    for(i = 0; i < 16; i=i+1)
      assign lq_base_cmp[i] = ~|(lq_base[i*32+:7] ^ wb_robid);
  endgenerate

  wire [15:0] lq_base_fwd_en = {16{wb_en}} & lq_valid & ~lq_base_rdy & lq_base_cmp;

  mux #(32,2) lq_base_next_mux[15:0](
    .sel(lq_base_fwd_en),
    .in({wb_result,rename_op1}),
    .out(lq_base_next));

  flop #(32) lq_base_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en | lq_base_fwd_en),
    .d(lq_base_next),
    .q(lq_base));

  flop lq_base_rdy_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(lq_base_fwd_en),
    .enable(lq_insert_en),
    .d(rename_op1ready),
    .q(lq_base_rdy));

  // lq_op2
  wire [(8*16)-1:0] lq_op2_next;

  wire [15:0] lq_op2_cmp;
  generate
    for(i = 0; i < 16; i=i+1)
      assign lq_op2_cmp[i] = ~|(lq_op2[i*8+:7] ^ wb_robid);
  endgenerate

  wire [15:0] lq_op2_fwd_en = {16{wb_en}} & lq_valid & ~lq_op2_rdy & lq_op2_cmp;

  mux #(8,2) lq_op2_next_mux[15:0](
    .sel(lq_op2_fwd_en),
    .in({wb_result[7:0],rename_op2[7:0]}),
    .out(lq_op2_next));

  flop #(8) lq_op2_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_insert_en | lq_op2_fwd_en),
    .d(lq_op2_next),
    .q(lq_op2));

  flop lq_op2_rdy_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(lq_op2_fwd_en),
    .enable(lq_insert_en),
    .d((~&rename_op[1:0]) | rename_op2ready),
    .q(lq_op2_rdy));

  // lq_addr
  wire [15:0] lq_addrgen_en = lq_addrgen_sel & {16{lq_addrgen_req}};

  flop #(32) lq_addr_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(lq_addrgen_en),
    .d(lq_addrgen_addr),
    .q(lq_addr));

  flop lq_addr_rdy_r[15:0](
    .clk(clk),
    .rst(lq_insert_en),
    .set(lq_addrgen_en),
    .enable(1'b0),
    .d(1'b0),
    .q(lq_addr_rdy));

  // lq_issued
  wire [15:0] lq_issue_en = lq_issue_sel & {16{lq_issue_beat}};

  flop lq_issued_r[15:0](
    .clk(clk),
    .rst(lq_insert_en),
    .set(lq_issue_en),
    .enable(1'b0),
    .d(1'b0),
    .q(lq_issued));

  // lq_complete, lq_error, lq_ecause, lq_data
  wire [15:0] dcache_lq_sel;
  decoder #(4) dcache_lq_sel_decoder(
    .in(dcache_lsq_lsqid),
    .out(dcache_lq_sel));

  wire [15:0] dcache_lq_en = dcache_lq_sel & {16{dcache_lsq_valid}};

  flop lq_complete_r[15:0](
    .clk(clk),
    .rst(lq_insert_en),
    .set(dcache_lq_en),
    .enable(1'b0),
    .d(1'b0),
    .q(lq_complete));

  flop lq_error_r[15:0](
    .clk(clk),
    .rst(lq_insert_en),
    .set(1'b0),
    .enable(dcache_lq_en),
    .d(dcache_lsq_error),
    .q(lq_error));

  flop #(5) lq_ecause_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(dcache_lq_en),
    .d(5'b0), // TODO
    .q(lq_ecause));

  flop #(32) lq_data_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(dcache_lq_en),
    .d(dcache_lsq_rdata),
    .q(lq_data));

  // load queue -> store queue interface (address conflict check)
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
    .clear_col_sel(sq_tail),
    .row_sel(lq_issue_sel),
    .col_sel(lq_sq_sel));

  // generate lq_sq_addr, lq_sq_wide
  wire [31:0] lq_sq_addr;
  wire [2:0]  lq_sq_type;
  premux #(32,16) lq_sq_addr_mux(lq_issue_sel, lq_addr, lq_sq_addr);
  premux #(3,16) lq_sq_type_mux(lq_issue_sel, lq_type, lq_sq_type);

  wire [15:0] lq_sq_addr_hit_hi, lq_sq_addr_hit_lo;
  generate
    for(i = 0; i < 16; i=i+1) begin
      assign lq_sq_addr_hit_hi[i] = ~|(sq_addr[i*32+:32][31:5] ^ lq_sq_addr[31:5]);
      assign lq_sq_addr_hit_lo[i] = ~|(sq_addr[i*32+:32][4:2] ^ lq_sq_addr[4:2]);
    end
  endgenerate

  // lq_sq_wide: enables 32-byte blocks for addr comparison (lbcmp)
  wire [15:0] lq_sq_en = lq_sq_sel & sq_valid;
  wire lq_sq_wide = &lq_sq_type[1:0];

  wire [15:0] lq_sq_hits = lq_sq_en & (~sq_addr_rdy |
                                       (lq_sq_addr_hit_hi &
                                        ({16{lq_sq_wide}} | lq_sq_addr_hit_lo)));
  assign lq_sq_hit = |lq_sq_hits;

  // -----------------------------------------------------------------store queue
  wire        sq_insert_beat = rename_lsq_write & rename_op[3] & ~sq_full;
  wire [15:0] sq_insert_en = {16{sq_insert_beat}} & sq_tail;

  wire [15:0] sq_issue_req = sq_head & sq_valid & sq_addr_rdy &
                             sq_issue_rdy & ~{16{rob_flush}};
  wire        sq_issue_ack = ~lq_issue_req & dcache_lsq_ready;
  wire [15:0] sq_issue_en = sq_issue_req & {16{sq_issue_ack}};
  wire        sq_issue_beat = |sq_issue_en;

  // sq_head
  onehot #(16) sq_head_r(
    .clk(clk),
    .rst(rst),
    .shift(sq_issue_beat),
    .out(sq_head));
  flop sq_head_pol_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(sq_issue_beat),
    .d(sq_head_pol ^ sq_head[15]),
    .q(sq_head_pol));

  // sq_mid
  onehot #(16) sq_mid_r(
    .clk(clk),
    .rst(rst),
    .shift(rob_ret_store),
    .out(sq_mid));
  flop sq_mid_pol_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(rob_ret_store),
    .d(sq_mid_pol ^ sq_mid[15]),
    .q(sq_mid_pol));

  // sq_tail
  wire sq_tail_pol_next;

  onehot_load #(16) sq_tail_r(
    .clk(clk),
    .rst(rst),
    .load(rob_flush),
    .load_val(sq_mid),
    .shift(sq_insert_beat),
    .out(sq_tail));
  mux #(1,2) sq_tail_pol_mux(
    .sel(rob_flush),
    .in({sq_mid_pol,sq_tail_pol ^ sq_tail[15]}),
    .out(sq_tail_pol_next));
  flop sq_tail_pol_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(sq_insert_beat | rob_flush),
    .d(sq_tail_pol_next),
    .q(sq_tail_pol));

  // sq_addrgen
  wire        sq_addrgen_req_in, sq_addrgen_req;
  wire [15:0] sq_addrgen_sel_in, sq_addrgen_sel;

  priarb #(16) sq_addrgen_arb(
    .req(sq_valid & sq_base_rdy & ~sq_addr_rdy & ~sq_addrgen_sel),
    .grant_valid(sq_addrgen_req_in),
    .grant(sq_addrgen_sel_in));

  flop sq_addrgen_req_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(1'b1),
    .d(sq_addrgen_req_in),
    .q(sq_addrgen_req));

  flop #(16) sq_addrgen_sel_r(
    .clk(clk),
    .rst(rst),
    .set(1'b0),
    .enable(1'b1),
    .d(sq_addrgen_sel_in),
    .q(sq_addrgen_sel));

  wire [31:0] sq_addrgen_base, sq_addrgen_imm;
  premux #(32,16) sq_addrgen_base_mux(
    .sel(sq_addrgen_sel),
    .in(sq_base),
    .out(sq_addrgen_base));
  premux #(32,16) sq_addrgen_imm_mux(
    .sel(sq_addrgen_sel),
    .in(sq_imm),
    .out(sq_addrgen_imm));

  wire [31:0] sq_addrgen_addr;
  rca #(32) sq_addrgen_addr_adder(
    .sub(1'b0),
    .a(sq_addrgen_base),
    .b(sq_addrgen_imm),
    .c(sq_addrgen_addr));

  // sq_valid
  // rob_flush: preserve retired but not yet issued insns
  wire [15:0] sq_valid_rst = {16{rst}} |
                             ({16{rob_flush}} & ~sq_issue_rdy) |
                             sq_issue_en;
  wire [15:0] sq_valid_set = ~{16{rob_flush}} & sq_insert_en;

  flop sq_valid_r[15:0](
    .clk(clk),
    .rst(sq_valid_rst),
    .set(sq_valid_set),
    .enable(1'b0),
    .d(1'b0),
    .q(sq_valid));

  // sq_base
  wire [(32*16)-1:0] sq_base_next;

  wire [15:0] sq_base_cmp;
  generate
    for(i = 0; i < 16; i=i+1)
      assign sq_base_cmp[i] = ~|(sq_base[i*32+:7] ^ wb_robid);
  endgenerate

  wire [15:0] sq_base_fwd_en = {16{wb_en}} & sq_valid & ~sq_base_rdy & sq_base_cmp;

  mux #(32,2) sq_base_next_mux[15:0](
    .sel(sq_base_fwd_en),
    .in({wb_result,rename_op1}),
    .out(sq_base_next));

  flop #(32) sq_base_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(sq_insert_en | sq_base_fwd_en),
    .d(sq_base_next),
    .q(sq_base));

  flop sq_base_rdy_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(sq_base_fwd_en),
    .enable(sq_insert_en),
    .d(rename_op1ready),
    .q(sq_base_rdy));

  // sq_addr
  wire [15:0] sq_addrgen_en = sq_addrgen_sel & {16{sq_addrgen_req}};

  flop #(32) sq_addr_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(sq_addrgen_en),
    .d(sq_addrgen_addr),
    .q(sq_addr));

  flop sq_addr_rdy_r[15:0](
    .clk(clk),
    .rst(sq_insert_en),
    .set(sq_addrgen_en),
    .enable(1'b0),
    .d(1'b0),
    .q(sq_addr_rdy));

  // sq_data
  wire [(32*16)-1:0] sq_data_next;

  wire [15:0] sq_data_cmp;
  generate
    for(i = 0; i < 16; i=i+1)
      assign sq_data_cmp[i] = ~|(sq_data[i*32+:7] ^ wb_robid);
  endgenerate

  wire [15:0] sq_data_fwd_en = {16{wb_en}} & sq_valid & ~sq_data_rdy & sq_data_cmp;

  mux #(32,2) sq_data_next_mux[15:0](
    .sel(sq_data_fwd_en),
    .in({wb_result,rename_op2}),
    .out(sq_data_next));

  flop #(32) sq_data_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(sq_insert_en | sq_data_fwd_en),
    .d(sq_data_next),
    .q(sq_data));

  flop sq_data_rdy_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(sq_data_fwd_en),
    .enable(sq_insert_en),
    .d(rename_op2ready),
    .q(sq_data_rdy));

  // sq_issue_rdy
  wire [15:0] sq_retire_en = sq_mid & {16{rob_ret_store}};

  flop sq_issue_rdy_r[15:0](
    .clk(clk),
    .rst(sq_insert_en),
    .set(sq_retire_en),
    .enable(1'b0),
    .d(1'b0),
    .q(sq_issue_rdy));

  // sq_type, sq_imm
  flop #(3) sq_type_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(sq_insert_en),
    .d(rename_op[2:0]),
    .q(sq_type));

  flop #(32) sq_imm_r[15:0](
    .clk(clk),
    .rst(1'b0),
    .set(1'b0),
    .enable(sq_insert_en),
    .d(rename_imm),
    .q(sq_imm));

`ifndef SYNTHESIS
  /*verilator lint_off WIDTH*/
  always @(posedge clk)
    if(rename_lsq_write & ~lsq_stall)
      top.tb_trace_lsq_dispatch(
        rename_robid,
        rename_op[3] ? ($clog2(sq_tail) | (1 << 4)) : $clog2(lq_insert_sel),
        rename_op,
        rename_op1,
        rename_op2);

  integer j;
  always @(posedge clk)
    if(lq_base_fwd_en != 0)
      for(j = 0; j < 16; j=j+1)
        if(lq_base_fwd_en[j])
          top.tb_trace_lsq_base(
            j,
            wb_result);

  integer k;
  always @(posedge clk)
    if(sq_base_fwd_en != 0)
      for(k = 0; k < 16; k=k+1)
        if(sq_base_fwd_en[k])
          top.tb_trace_lsq_base(
            16 + k,
            wb_result);

  integer l;
  always @(posedge clk)
    if(sq_data_fwd_en != 0)
      for(l = 0; l < 16; l=l+1)
        if(sq_data_fwd_en[l])
          top.tb_trace_lsq_wdata(
            16 + l,
            wb_result);

  always @(posedge clk)
    if(~rst)
      top.tb_log_lsq_inflight(
        lq_valid,
        sq_valid);
  /*verilator lint_on WIDTH*/
`endif

endmodule
