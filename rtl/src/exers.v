// reservation stations for execute units (scalu/mcalu)
module exers #(
  parameter RS_ENTRIES = 32
  )(
  input         clk,
  input         rst,

  // rename interface
  input         rename_exers_write,
  input [4:0]   rename_op,
  input [6:0]   rename_robid,
  input [5:0]   rename_rd,
  input         rename_op1ready,
  input [31:0]  rename_op1,
  input         rename_op2ready,
  input [31:0]  rename_op2,
  output     exers_stall,

  // common scalu/mcalu signals
  output [6:0]  exers_robid,
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
  input [6:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush);

  genvar i;
  wire[$clog2(RS_ENTRIES)-1:0] issue_idx;
  wire issue_valid;
  wire issue_stall;
  wire [$clog2(RS_ENTRIES)-1:0] insert_idx;
  wire rs_full;

  wire resolve_valid = (wb_valid & (~wb_error) & (~wb_rd[5]));
  
  wire [RS_ENTRIES-1:0] rs_valid;
  wire [(RS_ENTRIES*5)-1:0] rs_op;
  wire [(RS_ENTRIES*6)-1:0] rs_rd;
  wire [(RS_ENTRIES*7)-1:0] rs_robid;

  wire [RS_ENTRIES-1:0] rs_op1ready;
  wire [(RS_ENTRIES*32)-1:0] rs_op1;
  wire [RS_ENTRIES-1:0] rs_op2ready;
  wire [(RS_ENTRIES*32)-1:0] rs_op2;
  
  // One-hot insertion/issue vectors
  wire [RS_ENTRIES-1:0] issue_ohidx; // Assert issue_idx
  wire [RS_ENTRIES-1:0] insert_ohidx; // Assert insert_idx
  decoder #($clog2(RS_ENTRIES)) iss_dec (.in(issue_idx), .out(issue_ohidx));
  decoder #($clog2(RS_ENTRIES)) ins_dec (.in(insert_idx), .out(insert_ohidx));
  
  // Rst and set vectors for rs
  wire [RS_ENTRIES-1:0] rst_vec = ({RS_ENTRIES{rst|rob_flush}}) | ({RS_ENTRIES{issue_valid&~issue_stall}} & issue_ohidx);
  wire [RS_ENTRIES-1:0] insert_rs = {RS_ENTRIES{rename_exers_write&~exers_stall&~(rst|rob_flush)}} & insert_ohidx;
  // Associative Resolution vectors
  wire [RS_ENTRIES-1:0] resolve_rsop1; 
  wire [RS_ENTRIES-1:0] resolve_rsop2;

  generate
    for (i = 0; i < RS_ENTRIES; i = i+1) begin : resolve_gen
      assign resolve_rsop1[i] = resolve_valid & rs_valid[i] & (~rs_op1ready[i]) & 
                        (rs_op1[(32*i) +: 7] == wb_robid);
      assign resolve_rsop2[i] = resolve_valid & rs_valid[i] & (~rs_op2ready[i]) & 
                        (rs_op2[(32*i) +: 7] == wb_robid);
    end
  endgenerate

  // Valid bit for RS entries
  flop rs_valid_flop [RS_ENTRIES-1:0] 
  (.clk(clk), .set(insert_rs), .rst(rst_vec), .enable(1'b0), .d(1'b0), .q(rs_valid));

  // Single port entries
  flop #(5) rs_op_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(insert_rs), .d(rename_op), .q(rs_op));
  flop #(6) rs_rd_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(insert_rs), .d(rename_rd), .q(rs_rd));
  flop #(7) rs_robid_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(insert_rs), .d(rename_robid), .q(rs_robid));

  // Set when resolve, write data-in when insert
  flop rs_op1ready_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(resolve_rsop1), .rst(1'b0), .enable(insert_rs), 
   .d(rename_op1ready), .q(rs_op1ready));

  flop rs_op2ready_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(resolve_rsop2), .rst(1'b0), .enable(insert_rs), 
   .d(rename_op2ready), .q(rs_op2ready));

  // Dual port entries: From writeback and insert
  // Op1/2 inputs
  wire [(RS_ENTRIES*32)-1:0] op1_vec;
  wire [(RS_ENTRIES*32)-1:0] op2_vec;
  mux #(32, 2) rs_op1_mux [RS_ENTRIES-1:0] (.sel(resolve_rsop1), .in({wb_result, rename_op1}), .out(op1_vec));
  mux #(32, 2) rs_op2_mux [RS_ENTRIES-1:0] (.sel(resolve_rsop2), .in({wb_result, rename_op2}), .out(op2_vec));
  
  flop #(32) rs_op1_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(insert_rs|resolve_rsop1), 
   .d(op1_vec), .q(rs_op1));
  flop #(32) rs_op2_flop [RS_ENTRIES-1:0]
  (.clk(clk), .set(1'b0), .rst(1'b0), .enable(insert_rs|resolve_rsop2), 
   .d(op2_vec), .q(rs_op2));


  // Issue logic
  wire issue_invalid;
  wire [RS_ENTRIES-1:0] issue_ready = rs_valid & rs_op1ready & rs_op2ready;
  
  priencoder #(RS_ENTRIES, 1) issue_rs_prippf (
    .in(issue_ready),
    .invalid(issue_invalid),
    .out(issue_idx));
  assign issue_valid = ~issue_invalid;

  // Functional Issue Unit Arbitration 
  wire is_sc_op = (~&exers_scalu_op[4:3]);
  wire [3:0] issue_status = {is_sc_op & ~scalu1_stall, is_sc_op & ~scalu0_stall, ~mcalu1_stall, ~mcalu0_stall}; // SCALU1: lowest priority, MCALU1: highest
  wire [3:0] issue_vec;
  privector #(4, 1) issue_alu_pripff (
    .in(issue_status),
    .invalid(issue_stall),
    .out(issue_vec));

  assign {exers_scalu1_issue, exers_scalu0_issue, 
    exers_mcalu1_issue, exers_mcalu0_issue} = issue_vec & {4{issue_valid}};

  // Insert logic
  priencoder #(RS_ENTRIES, 0) insert_rs_prippf (
    .in(rs_valid),
    .invalid(rs_full),
    .out(insert_idx));

  // Outputs to issue
  assign exers_robid = rs_robid[(7*issue_idx) +: 7];
  assign exers_rd = rs_rd[(6*issue_idx) +: 6];
  assign exers_op1 = rs_op1[(32*issue_idx) +: 32];
  assign exers_op2 = rs_op2[(32*issue_idx) +: 32];
  assign exers_mcalu_op = rs_op[(5*issue_idx) +: 5];
  assign exers_scalu_op = rs_op[(5*issue_idx) +: 5];
  assign exers_stall = rs_full;

endmodule
