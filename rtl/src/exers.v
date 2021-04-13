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

  integer i;
  reg [RS_ENTRIES-1:0] rs_valid;
  reg [4:0]            rs_op[RS_ENTRIES-1:0];
  reg [5:0]            rs_rd[RS_ENTRIES-1:0];
  reg [6:0]            rs_robid[RS_ENTRIES-1:0];

  reg [RS_ENTRIES-1:0] rs_op1ready;
  reg [31:0]           rs_op1[RS_ENTRIES-1:0];
  reg [RS_ENTRIES-1:0] rs_op2ready;
  reg [31:0]           rs_op2[RS_ENTRIES-1:0];

  wire[$clog2(RS_ENTRIES)-1:0] issue_idx;
  wire issue_valid;
  wire issue_stall;
  wire [$clog2(RS_ENTRIES)-1:0] insert_idx;
  wire rs_full;

  wire resolve_valid = (wb_valid & (~wb_error) & (~wb_rd[5]));
  
  /*wire [RS_ENTRIES-1:0] rs_valid;
  wire [4:0]            rs_op[RS_ENTRIES-1:0];
  wire [5:0]            rs_rd[RS_ENTRIES-1:0];
  wire [6:0]            rs_robid[RS_ENTRIES-1:0];

  wire [RS_ENTRIES-1:0] rs_op1ready;
  wire [31:0]           rs_op1[RS_ENTRIES-1:0];
  wire [RS_ENTRIES-1:0] rs_op2ready;
  wire [31:0]           rs_op2[RS_ENTRIES-1:0];*/
  
  // One-hot insertion/issue vectors
  wire [RS_ENTRIES-1:0] insert_rs; // Assert insert_idx
  wire [RS_ENTRIES-1:0] issue_rs; // Assert issue_idx
  // Associative Resolution vectors
  wire [RS_ENTRIES-1:0] resolve_rsop1; 
  wire [RS_ENTRIES-1:0] resolve_rsop2;

  // Generate inputs/outputs for each RS entry
  /*genvar i;
  generate
    for (i = 0; i < RS_ENTRIES; i = i+1) begin
      `FLOP2_RS (rs_valid[i], 1, 
          rst|rob_flush|issue_rs[i], insert_rs[i]);

      `FLOP2_E (rs_op[i], 5, insert_rs[i], rename_op);
      `FLOP2_E (rs_rd[i], 6, insert_rs[i], rename_rd);
      `FLOP2_E (rs_robid[i], 7, insert_rs[i], rename_robid);

      `FLOP2_ES (rs_op1ready[i], 1, insert_rs[i], rename_op1ready, resolve_rsop1[i]);
      `FLOP2_ES (rs_op2ready[i], 1, insert_rs[i], rename_op1ready, resolve_rsop2[i]);
      
      wire [31:0] op1_i;
      `MUX2X1 (op1_i, 32, resolve_rsop1[i], rename_op1, wb_result);
      `FLOP2_E (rs_op1[i], 32, insert_rs[i]|resolve_rsop1[i], op1_i);

      wire [31:0] op2_i;
      `MUX2X1 (op2_i, 32, resolve_rsop2[i], rename_op2, wb_result);
      `FLOP2_E (rs_op2[i], 32, insert_rs[i]|resolve_rsop2[i], op2_i);

    end
  endgenerate*/

  // === 

  always @(posedge clk) begin
    // Issue latch
    if (issue_valid & (~issue_stall)) begin
      rs_valid[issue_idx] <= 1'b0;
    end
    // Insertion latch
    if (rename_exers_write & (~exers_stall)) begin
      rs_valid[insert_idx] <= 1'b1;
      rs_op[insert_idx] <= rename_op;
      rs_rd[insert_idx] <= rename_rd;
      rs_robid[insert_idx] <= rename_robid;
      rs_op1ready[insert_idx] <= rename_op1ready;
      rs_op1[insert_idx] <= rename_op1;
      rs_op2ready[insert_idx] <= rename_op2ready;
      rs_op2[insert_idx] <= rename_op2;
    end
    // Dependency resolution: matching tags on valid writeback/uses rd
    for (i = 0; i  < RS_ENTRIES; i = i + 1) begin
      if (resolve_valid & rs_valid[i] & (~rs_op1ready[i]) & (rs_op1[i][6:0] == wb_robid)) begin
        rs_op1ready[i] <= 1'b1;
        rs_op1[i] <= wb_result;
      end
      if (resolve_valid & rs_valid[i] & (~rs_op2ready[i]) & (rs_op2[i][6:0] == wb_robid)) begin
        rs_op2ready[i] <= 1'b1;
        rs_op2[i] <= wb_result;
      end
    end
    // Reset/flush logic (highest priority)
    if (rst | rob_flush) begin
      rs_valid <= 32'h0;
    end
  end

  // ====

  // Issue logic
  wire issue_invalid;
  wire [RS_ENTRIES-1:0] issue_ready = rs_valid & rs_op1ready & rs_op2ready;
  
  priencoder #(RS_ENTRIES, 1) issue_rs_prippf (
    .in(issue_ready),
    .invalid(issue_invalid),
    .out(issue_idx));
  assign issue_valid = ~issue_invalid;

  // Functional Issue Unit Arbitration 
  wire is_sc_op = (~&rs_op[issue_idx][4:3]);
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
  assign exers_robid = rs_robid[issue_idx];
  assign exers_rd = rs_rd[issue_idx];
  assign exers_op1 = rs_op1[issue_idx];
  assign exers_op2 = rs_op2[issue_idx];
  assign exers_mcalu_op = rs_op[issue_idx];
  assign exers_scalu_op = rs_op[issue_idx];
  assign exers_stall = rs_full;

endmodule
