// multi-cycle alu
module mcalu(
  input             clk,
  input             rst,

  // exers interface
  input             exers_mcalu_issue,
  input [4:0]       exers_mcalu_op,
  input [6:0]       exers_robid,
  input [5:0]       exers_rd,
  input [31:0]      exers_op1,
  input [31:0]      exers_op2,
  output            mcalu_stall,

  // wb interface
  output            mcalu_valid,
  output            mcalu_error,
  output [4:0]      mcalu_ecause,
  output [6:0]      mcalu_robid,
  output [5:0]      mcalu_rd,
  output [31:0]     mcalu_result,
  input             wb_mcalu_stall,

  // rob interface
  input             rob_flush);

  wire        valid;
  wire [4:0]  op;
  wire [6:0]  robid;
  wire [5:0]  rd;
  wire [31:0] op1;
  wire [31:0] op2;
  // Stage latches
  flop valid_flop (.clk(clk), .set(1'b0), .rst(rst|rob_flush), .enable(~mcalu_stall),
    .d(exers_mcalu_issue), .q(valid));

  flop #(5) op_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(~mcalu_stall),
    .d(exers_mcalu_op), .q(op));
  flop #(7) robid_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(~mcalu_stall),
    .d(exers_robid), .q(robid));
  flop #(6) rd_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(~mcalu_stall),
    .d(exers_rd), .q(rd));
  flop #(32) op1_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(~mcalu_stall),
    .d(exers_op1), .q(op1));
  flop #(32) op2_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(~mcalu_stall),
    .d(exers_op2), .q(op2));

  /*always @(posedge clk)
    if (rst | rob_flush)
      valid <= 0;
    else if (~mcalu_stall) begin
      valid <= exers_mcalu_issue;
      op <= exers_mcalu_op;
      robid <= exers_robid;
      rd <= exers_rd;
      op1 <= exers_op1;
      op2 <= exers_op2;
    end*/


  wire        mul_done, div_done;
  wire [31:0] sc_result, mul_result, div_result;

  wire is_mc_op = &op[4:3];
  wire done = ~is_mc_op | mul_done | div_done;

  // MC Outputs
  assign mcalu_valid = valid & done;
  assign mcalu_error = 0;
  assign mcalu_ecause = 0;
  assign mcalu_robid = robid;
  assign mcalu_rd = rd;
  assign mcalu_stall = valid & (~done | wb_mcalu_stall);

  // Result sequencing
  wire [31:0] comp_result;
  mux #(32, 2) comp_result_flop (.sel(op[2]), .in({div_result, mul_result}), .out(comp_result));

  mux #(32, 2) mcalu_result_flop (.sel(is_mc_op), .in({comp_result, sc_result}), .out(mcalu_result));

  /*always @(*)
    if(~is_mc_op)
      mcalu_result = sc_result;
    else if(~op[2])
      mcalu_result = mul_result;
    else
      mcalu_result = div_result;*/

  // Simple Ops  
  alu_simple sc_alu(
    .op(op),
    .op1(op1),
    .op2(op2),
    .sc_result(sc_result));

  // Complex Ops
  mul mul(
    .clk(clk),
    .rst(rst | rob_flush),
    .req(valid & is_mc_op & ~op[2]),
    .op(op[1:0]),
    .op1(op1),
    .op2(op2),
    .done(mul_done),
    .result(mul_result),
    .stall(wb_mcalu_stall));

  div div(
    .clk(clk),
    .rst(rst | rob_flush),
    .req(valid & is_mc_op & op[2]),
    .op(op[1:0]),
    .op1(op1),
    .op2(op2),
    .done(div_done),
    .result(div_result),
    .stall(wb_mcalu_stall));

endmodule
