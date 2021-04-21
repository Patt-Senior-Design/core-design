// register alias table
module rat(
  input             clk,
  input             rst,

  // rename interface
  input [4:0]       rename_rs1,
  input [4:0]       rename_rs2,
  input             rename_alloc,
  input [4:0]       rename_rd,
  input [6:0]       rename_robid,
  output            rat_rs1_valid,
  output [31:0] rat_rs1_tagval,
  output            rat_rs2_valid,
  output [31:0] rat_rs2_tagval,

  // wb interface
  input             wb_valid,
  input             wb_error,
  input [6:0]       wb_robid,
  input [5:0]       wb_rd,
  input [31:0]      wb_result,

  // rob interface
  input             rob_flush,
  input             rob_ret_commit,
  input [4:0]       rob_ret_rd,
  input [31:0]      rob_ret_result);

  wire [31:0] rat_valid;
  wire [31:0] rat_committed;
  wire [(32*32)-1:0] rat_comm_val;
  wire [(32*32)-1:0] rat_spec_val;
  wire [(7*32)-1:0] rat_tag;

  wire        valid_rs1, valid_rs2;
  wire        committed_rs1, committed_rs2;
  wire [31:0] comm_val_rs1, comm_val_rs2;
  wire [31:0] spec_val_rs1, spec_val_rs2;
  wire [6:0]  tag_rs1, tag_rs2, tag_wb;

  
  wire wb_write = wb_valid & ~wb_error & ~wb_rd[5] & (wb_robid == tag_wb);

  wire fwd_rs1, fwd_rs2;
  assign fwd_rs1 = wb_write & (wb_rd[4:0] == rename_rs1);
  assign fwd_rs2 = wb_write & (wb_rd[4:0] == rename_rs2);

  // Get one-hot for rename:{rs1, rs2, rd}, ret:{rd}, wb:{rd}
  wire [31:0] rs1_ohidx;
  wire [31:0] rs2_ohidx;
  wire [31:0] rd_ohidx;
  wire [31:0] ret_ohidx;
  wire [31:0] wb_ohidx;
  decoder #(5) rs1_ohidx_dec (.in(rename_rs1), .out(rs1_ohidx));
  decoder #(5) rs2_ohidx_dec (.in(rename_rs2), .out(rs2_ohidx));
  decoder #(5) rd_dec (.in(rename_rd), .out(rd_ohidx));
  decoder #(5) rob_ret_rd_dec (.in(rob_ret_rd), .out(ret_ohidx));
  decoder #(5) wb_rd_dec (.in(wb_rd[4:0]), .out(wb_ohidx));
  
  wire [31:0] wb_en = wb_ohidx & {32{wb_write}};
  wire [31:0] alloc_en = rd_ohidx & {32{rename_alloc}};

  // flag store read
  premux #(1, 32) valid_rs1_mux (.sel(rs1_ohidx), .in(rat_valid), .out(valid_rs1));
  premux #(1, 32) valid_rs2_mux (.sel(rs2_ohidx), .in(rat_valid), .out(valid_rs2));

  premux #(1, 32) committed_rs1_mux (.sel(rs1_ohidx), .in(rat_committed), .out(committed_rs1));
  premux #(1, 32) committed_rs2_mux (.sel(rs2_ohidx), .in(rat_committed), .out(committed_rs2));
  // ==
  // flag store write
  // if wb_rd == rename_rd, clear has precedence over set
  wire wb_rd_conflict = rename_alloc & (wb_rd[4:0] == rename_rd);
  wire [31:0] rst_vec = {32{rst|rob_flush}};
  wire [31:0] valid_set_vec = (wb_en & {32{~wb_rd_conflict}}) | rst_vec;
  wire [31:0] valid_rst_vec = alloc_en & ~rst_vec;

  flop rat_valid_flop [31:0] (.clk(clk), .set(valid_set_vec), .rst(valid_rst_vec), .enable(1'b0), 
      .d(32'b0), .q(rat_valid));
  flop rat_committed_flop [31:0] (.clk(clk), .set(rst_vec), .rst(valid_rst_vec), .enable(1'b0),
      .d(32'b0), .q(rat_committed));


  // committed data read
  premux #(32, 32) comm_val_rs1_mux (.sel(rs1_ohidx), .in(rat_comm_val), .out(comm_val_rs1));
  premux #(32, 32) comm_val_rs2_mux (.sel(rs2_ohidx), .in(rat_comm_val), .out(comm_val_rs2));
  
  // committed data write
  wire [31:0] comm_val_en = ret_ohidx & {32{rob_ret_commit}};
  flop #(32) rat_comm_val_flop [31:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(comm_val_en), .d(rob_ret_result), .q(rat_comm_val));


  // speculative data read
  premux #(32, 32) spec_val_rs1_mux (.sel(rs1_ohidx), .in(rat_spec_val), .out(spec_val_rs1));
  premux #(32, 32) spec_val_rs2_mux (.sel(rs2_ohidx), .in(rat_spec_val), .out(spec_val_rs2));
  
  // speculative data write
  flop #(32) rat_spec_val_flop [31:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(wb_en), .d(wb_result), .q(rat_spec_val));


  // tag store read
  premux #(7, 32) tag_rs1_mux (.sel(rs1_ohidx), .in(rat_tag), .out(tag_rs1));
  premux #(7, 32) tag_rs2_mux (.sel(rs2_ohidx), .in(rat_tag), .out(tag_rs2));
  premux #(7, 32) tag_wb_mux (.sel(wb_ohidx), .in(rat_tag), .out(tag_wb));

  // tag store write
  flop #(7) rat_tag_flop [31:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(alloc_en), .d(rename_robid), .q(rat_tag));


  // Outputs to rename
  assign rat_rs1_valid = valid_rs1 | fwd_rs1;
  assign rat_rs2_valid = valid_rs2 | fwd_rs2;

  // RS1 val
  wire [3:0] rs1_tagval_sel = {fwd_rs1, committed_rs1, 
    ~committed_rs1 & valid_rs1, ~fwd_rs1 & ~committed_rs1 & ~valid_rs1};
  wire [(32*4)-1:0] rs1_tagval_in = {wb_result, comm_val_rs1, spec_val_rs1, 25'b0,tag_rs1};
  
  wire [31:0] rs1_tagval;
  premux #(32, 4) rat_rs1_tagval_mux (.sel(rs1_tagval_sel), 
      .in(rs1_tagval_in), .out(rs1_tagval));
  assign rat_rs1_tagval = rs1_tagval & {32{|rename_rs1}}; // if rs1=0, force to 0

  // RS2 val
  wire [3:0] rs2_tagval_sel = {fwd_rs2, committed_rs2, 
    ~committed_rs2 & valid_rs2, ~fwd_rs2 & ~committed_rs2 & ~valid_rs2};
  wire [(32*4)-1:0] rs2_tagval_in = {wb_result, comm_val_rs2, spec_val_rs2, 25'b0,tag_rs2};
  
  wire [31:0] rs2_tagval;
  premux #(32, 4) rat_rs2_tagval_mux (.sel(rs2_tagval_sel), 
      .in(rs2_tagval_in), .out(rs2_tagval));
  assign rat_rs2_tagval = rs2_tagval & {32{|rename_rs2}}; // if rs2=0, force to 0

endmodule
