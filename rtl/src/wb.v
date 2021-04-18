// writeback (common data bus)
// TBD: Merge all the interfaces into one array
module wb(
  input         clk,
  input         rst,

  // rename interface (highest priority)
  input         rename_wb_valid,
  input [6:0]   rename_robid,
  input [5:0]   rename_rd,
  input [31:2]  rename_wb_result,

  // scalu0 interface
  input         scalu0_valid,
  input         scalu0_error,
  input [4:0]   scalu0_ecause,
  input [6:0]   scalu0_robid,
  input [5:0]   scalu0_rd,
  input [31:0]  scalu0_result,
  output        wb_scalu0_stall,

  // scalu1 interface
  input         scalu1_valid,
  input         scalu1_error,
  input [4:0]   scalu1_ecause,
  input [6:0]   scalu1_robid,
  input [5:0]   scalu1_rd,
  input [31:0]  scalu1_result,
  output        wb_scalu1_stall,

  // mcalu0 interface
  input         mcalu0_valid,
  input         mcalu0_error,
  input [4:0]   mcalu0_ecause,
  input [6:0]   mcalu0_robid,
  input [5:0]   mcalu0_rd,
  input [31:0]  mcalu0_result,
  output        wb_mcalu0_stall,

  // mcalu1 interface
  input         mcalu1_valid,
  input         mcalu1_error,
  input [4:0]   mcalu1_ecause,
  input [6:0]   mcalu1_robid,
  input [5:0]   mcalu1_rd,
  input [31:0]  mcalu1_result,
  output        wb_mcalu1_stall,

  // lsq interface
  input         lsq_wb_valid,
  input         lsq_wb_error,
  input [4:0]   lsq_wb_ecause,
  input [6:0]   lsq_wb_robid,
  input [5:0]   lsq_wb_rd,
  input [31:0]  lsq_wb_result,
  output        wb_lsq_stall,

  // csr interface
  input         csr_valid,
  input         csr_error,
  input [4:0]   csr_ecause,
  input [6:0]   csr_robid,
  input [5:0]   csr_rd,
  input [31:0]  csr_result,

  // common output signals
  output        wb_valid,
  output        wb_error,
  output [4:0]  wb_ecause,
  output [6:0]  wb_robid,
  output [5:0]  wb_rd,
  output [31:0] wb_result,

  // rob interface
  input         rob_flush);

  // Latches declarations for all incoming stages
  wire         rename_valid_r;
  wire [6:0]   rename_robid_r;
  wire [4:0]   rename_rd_r;
  wire [31:0]  rename_result_r;

  wire         scalu0_valid_r;
  wire         scalu0_error_r;
  wire [4:0]   scalu0_ecause_r;
  wire [6:0]   scalu0_robid_r;
  wire [5:0]   scalu0_rd_r;
  wire [31:0]  scalu0_result_r;

  wire         scalu1_valid_r;
  wire         scalu1_error_r;
  wire [4:0]   scalu1_ecause_r;
  wire [6:0]   scalu1_robid_r;
  wire [5:0]   scalu1_rd_r;
  wire [31:0]  scalu1_result_r;

  wire         mcalu0_valid_r;
  wire         mcalu0_error_r;
  wire [4:0]   mcalu0_ecause_r;
  wire [6:0]   mcalu0_robid_r;
  wire [5:0]   mcalu0_rd_r;
  wire [31:0]  mcalu0_result_r;

  wire         mcalu1_valid_r;
  wire         mcalu1_error_r;
  wire [4:0]   mcalu1_ecause_r;
  wire [6:0]   mcalu1_robid_r;
  wire [5:0]   mcalu1_rd_r;
  wire [31:0]  mcalu1_result_r;

  wire         lsq_valid_r;
  wire         lsq_error_r;
  wire [4:0]   lsq_ecause_r;
  wire [6:0]   lsq_robid_r;
  wire [5:0]   lsq_rd_r;
  wire [31:0]  lsq_result_r;

  // Rename latches
  flop rename_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(1'b1),
      .d(rename_wb_valid), .q(rename_valid_r));
  flop #(7) rename_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(1'b1),
      .d(rename_robid), .q(rename_robid_r));
  flop #(5) rename_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(1'b1),
      .d(rename_rd[4:0]), .q(rename_rd_r));
  flop #(32) rename_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(1'b1),
      .d({rename_wb_result, 2'b0}), .q(rename_result_r));

  // scalu0 latches: choose between csr and scalu0
  wire scin0_valid = csr_valid | scalu0_valid;
  wire scin0_error;
  wire [4:0] scin0_ecause;
  wire [6:0] scin0_robid;
  wire [5:0] scin0_rd;
  wire [31:0] scin0_result;
  
  mux #(1, 2) scin0_error_mux (.sel(csr_valid), .in({csr_error, scalu0_error}), .out(scin0_error));
  mux #(5, 2) scin0_ecause_mux (.sel(csr_valid), .in({csr_ecause, scalu0_ecause}), .out(scin0_ecause));
  mux #(7, 2) scin0_robid_mux (.sel(csr_valid), .in({csr_robid, scalu0_robid}), .out(scin0_robid));
  mux #(6, 2) scin0_rd_mux (.sel(csr_valid), .in({csr_rd, scalu0_rd}), .out(scin0_rd));
  mux #(32, 2) scin0_result_mux (.sel(csr_valid), .in({csr_result, scalu0_result}), .out(scin0_result));

  flop scalu0_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_valid), .q(scalu0_valid_r));
  flop scalu0_error_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_error), .q(scalu0_error_r));
  flop #(5) scalu0_ecause_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_ecause), .q(scalu0_ecause_r));
  flop #(7) scalu0_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_robid), .q(scalu0_robid_r));
  flop #(6) scalu0_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_rd), .q(scalu0_rd_r));
  flop #(32) scalu0_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu0_stall),
      .d(scin0_result), .q(scalu0_result_r));
  
  
  // scalu1 latches
  flop scalu1_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_valid), .q(scalu1_valid_r));
  flop scalu1_error_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_error), .q(scalu1_error_r));
  flop #(5) scalu1_ecause_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_ecause), .q(scalu1_ecause_r));
  flop #(7) scalu1_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_robid), .q(scalu1_robid_r));
  flop #(6) scalu1_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_rd), .q(scalu1_rd_r));
  flop #(32) scalu1_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_scalu1_stall),
      .d(scalu1_result), .q(scalu1_result_r));


  // mcalu0 latches
  flop mcalu0_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_valid), .q(mcalu0_valid_r));
  flop mcalu0_error_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_error), .q(mcalu0_error_r));
  flop #(5) mcalu0_ecause_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_ecause), .q(mcalu0_ecause_r));
  flop #(7) mcalu0_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_robid), .q(mcalu0_robid_r));
  flop #(6) mcalu0_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_rd), .q(mcalu0_rd_r));
  flop #(32) mcalu0_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu0_stall),
      .d(mcalu0_result), .q(mcalu0_result_r));

  // mcalu1 latches
  flop mcalu1_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_valid), .q(mcalu1_valid_r));
  flop mcalu1_error_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_error), .q(mcalu1_error_r));
  flop #(5) mcalu1_ecause_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_ecause), .q(mcalu1_ecause_r));
  flop #(7) mcalu1_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_robid), .q(mcalu1_robid_r));
  flop #(6) mcalu1_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_rd), .q(mcalu1_rd_r));
  flop #(32) mcalu1_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_mcalu1_stall),
      .d(mcalu1_result), .q(mcalu1_result_r));

  // lsq latches
  flop lsq_valid_r_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_valid), .q(lsq_valid_r));
  flop lsq_error_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_error), .q(lsq_error_r));
  flop #(5) lsq_ecause_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_ecause), .q(lsq_ecause_r));
  flop #(7) lsq_robid_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_robid), .q(lsq_robid_r));
  flop #(6) lsq_rd_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_rd), .q(lsq_rd_r));
  flop #(32) lsq_result_r_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~wb_lsq_stall),
      .d(lsq_wb_result), .q(lsq_result_r));



  // Arbitration for writeback outputs
  wire [5:0] arb_valid = {scalu1_valid_r, scalu0_valid_r, mcalu1_valid_r,
    mcalu0_valid_r, lsq_valid_r, rename_valid_r};

  wire [7:0] arb_privalid;
  wire wb_invalid;
  // Only 6, but must be power of 2
  privector #(8, 1) arb_prippf (
    .in({2'b0, arb_valid}),
    .invalid(wb_invalid),
    .out(arb_privalid));
  
  assign wb_valid = ~wb_invalid;
  wire [5:0] arb_select = arb_privalid[5:0];

  assign {wb_scalu1_stall, wb_scalu0_stall, wb_mcalu1_stall, 
    wb_mcalu0_stall, wb_lsq_stall} = arb_valid[5:1] & ~arb_select[5:1]; // Mask out arbitrated value
  
  // Writeback outputs
  premux #(1, 6) wb_error_mux (.sel(arb_select), 
      .in({scalu1_error_r, scalu0_error_r, mcalu1_error_r, mcalu0_error_r, lsq_error_r, 1'b0}),
      .out(wb_error));

  premux #(5, 6) wb_ecause_mux (.sel(arb_select), 
      .in({scalu1_ecause_r, scalu0_ecause_r, mcalu1_ecause_r, mcalu0_ecause_r, lsq_ecause_r, 5'b0}),
      .out(wb_ecause));

  premux #(7, 6) wb_robid_mux (.sel(arb_select), 
      .in({scalu1_robid_r, scalu0_robid_r, mcalu1_robid_r, mcalu0_robid_r, lsq_robid_r, rename_robid_r}),
      .out(wb_robid));

  premux #(6, 6) wb_rd_mux (.sel(arb_select), 
      .in({scalu1_rd_r, scalu0_rd_r, mcalu1_rd_r, mcalu0_rd_r, lsq_rd_r, 1'b0, rename_rd_r}),
      .out(wb_rd));

  premux #(32, 6) wb_result_mux (.sel(arb_select), 
      .in({scalu1_result_r, scalu0_result_r, mcalu1_result_r, mcalu0_result_r, lsq_result_r, rename_result_r}),
      .out(wb_result));

endmodule
