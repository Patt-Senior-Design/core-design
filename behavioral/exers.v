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
  output reg    exers_stall,

  // common scalu/mcalu signals
  output reg[6:0]  exers_robid,
  output reg[5:0]  exers_rd,
  output reg[31:0] exers_op1,
  output reg[31:0] exers_op2,

  // scalu interface
  output reg       exers_scalu0_issue,
  output reg       exers_scalu1_issue,
  output reg [4:0]  exers_scalu_op,
  input         scalu0_stall,
  input         scalu1_stall,

  // mcalu interface
  output reg       exers_mcalu0_issue,
  output reg       exers_mcalu1_issue,
  output reg [4:0]  exers_mcalu_op,
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

  reg[$clog2(RS_ENTRIES)-1:0] issue_idx;
  reg issue_valid;
  reg issue_stall;
  reg [3:0] fu_issue_q;
  reg[$clog2(RS_ENTRIES)-1:0] insert_idx;
  reg rs_full;
  reg is_sc_op;

  wire resolve_valid = (wb_valid & (~wb_error) & (~wb_rd[5]));

  // Find empty entry to insert into or ready entry to issue (priority encoder)
  // MSB tells you whether index is found or not
  function automatic [$clog2(RS_ENTRIES):0] find_idx 
    (input[RS_ENTRIES-1:0] vector, input bit_val);
    integer j;
    begin
      for (j = 0; j < RS_ENTRIES; j++) 
        if (vector[j] == bit_val) 
          find_idx[$clog2(RS_ENTRIES)-1:0] = j;
      find_idx[$clog2(RS_ENTRIES)] = (bit_val ? (| vector) : (& vector));
    end
  endfunction

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
      if (resolve_valid & (~rs_op1ready[i]) & (rs_op1[i][6:0] == wb_robid)) begin
        rs_op1ready[i] <= 1'b1;
        rs_op1[i] <= wb_result;
      end
      if (resolve_valid & (~rs_op2ready[i]) & (rs_op2[i][6:0] == wb_robid)) begin
        rs_op2ready[i] <= 1'b1;
        rs_op2[i] <= wb_result;
      end
    end
    // Reset/flush logic (highest priority)
    if (rst | rob_flush) begin
      rs_valid <= 32'h0;
    end
  end

  always @(*) begin
    // Issue
    {issue_valid, issue_idx} = find_idx(rs_valid & rs_op1ready & rs_op2ready, 1);
    exers_robid = rs_robid[issue_idx];
    exers_rd = rs_rd[issue_idx];
    exers_op1 = rs_op1[issue_idx];
    exers_op2 = rs_op2[issue_idx];
    exers_mcalu_op = rs_op[issue_idx];
    exers_scalu_op = rs_op[issue_idx];

    is_sc_op = (~& rs_op[issue_idx][4:3]);
    // NOTE: Can be modelled as issue array and stall array directly at inputs
    fu_issue_q = {is_sc_op & (~scalu0_stall), is_sc_op & (~scalu1_stall), ~mcalu0_stall, ~mcalu1_stall};
    casez(fu_issue_q)
      4'b1???: {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue} = 4'b1000;
      4'b01??: {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue} = 4'b0100;
      4'b001?: {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue} = 4'b0010;
      4'b0001: {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue} = 4'b0001;
      default: {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue} = 4'b0000;
    endcase
    issue_stall = (~| {exers_scalu0_issue, exers_scalu1_issue, exers_mcalu0_issue, exers_mcalu1_issue});

    // Insertion index: Use issue_idx if issued
    {rs_full, insert_idx} = find_idx(rs_valid, 0);
    insert_idx = (issue_valid & (~issue_stall) ? issue_idx : insert_idx);

    // Stall combinational
    exers_stall = (rs_full & (~issue_stall));
  end
  
endmodule
