// 32 x 32 multiplier
module mul(
  input         clk,
  input         rst,

  input         req,
  input [1:0]   op,
  input [31:0]  op1,
  input [31:0]  op2,

  output        done,
  output [31:0] result,
  input         stall);

  // Multiplier state
  wire        x0;
  wire [3:0]  iter;
  wire [65:0] acc;
  wire [1:0]  state;

  // INIT: 00, PROG: 01, PROG_FINAL: 10
  wire INIT_STATE = ~|state;
  wire PROG_STATE = state[0];
  wire PROG_FINAL_STATE = state[1];

  // Sign extension
  wire op1_sgn = op1[31] & (op[1] ^ op[0]);

  wire [65:0] acc_se = $signed(acc) >>> 2;

  // Booth encoding
  wire x2, x1;
  wire single, double, neg;

  assign {x2, x1} = acc[1:0];
  assign single = x1 ^ x0;
  assign double = ((~x2 & x1 & x0) | (x2 & (~x1) & (~x0)));
  assign neg = x2;

  // Partial product
  wire [33:0] pp_single = { {2{op1_sgn}}, op1 };
  wire [33:0] pp_double = { op1_sgn, op1, 1'b0 };
  
  wire [33:0] pp_unsigned;
  wire [33:0] pp_signed = {34{neg}} ^ pp_unsigned;
  premux #(34, 2) pp_unsigned_mux (.sel({double, single}), 
      .in({pp_double, pp_single}), .out(pp_unsigned));

  wire [33:0] pp_final = {34{x0 & ~(~op[1] & op[0])}} & {2'b0, op1};

  // Net partial product for iteration without negation correction
  wire [33:0] ptl_prod_i;
  mux #(34, 2) ptl_prod_i_mux (.sel(PROG_FINAL_STATE),
      .in({pp_final, pp_signed}), .out(ptl_prod_i));
    
  // Extra MSB, 2 extra bits for negation correction
  wire [35:0] ptl_prod = {ptl_prod_i,1'b0,x0};


  // State Machine
  wire        x0_c;
  wire [3:0]  iter_c;
  wire [65:0] acc_c;
  wire [1:0]  next_state;

  // Output
  wire [63:0] mul_result = acc_c[63:0];

  // Output sync for done and result: PROG_FINAL = 2'b10
  assign done = PROG_FINAL_STATE;
  mux #(32, 2) result_mux (.sel(|op[1:0]), .in(mul_result), .out(result));

  // iter == 1
  wire iter_done = ~|iter[3:1] & iter[0];
  wire state_enable = (INIT_STATE & req) | (PROG_STATE & iter_done) | (PROG_FINAL_STATE & ~stall);
  // INIT = 2'b00 so assert rst
  flop #(2) state_flop (.clk(clk), .rst(rst), .set(1'b0), .enable(state_enable), .d(next_state), 
      .q(state));
  assign next_state = {PROG_STATE, INIT_STATE};

  // x0 = 0 on INIT, assign during PROG
  flop x0_flop (.clk(clk), .rst(INIT_STATE), .set(1'b0), .enable(PROG_STATE), .d(x0_c), .q(x0));
  assign x0_c = acc[1] & state[0];

  // iter = 0 on INIT, assign during PROG
  flop #(4) iter_flop (.clk(clk), .rst(INIT_STATE), .set(1'b0), .enable(PROG_STATE), 
      .d(iter_c), .q(iter));
  `SUB(4, iter_c, iter, 4'h1);


  // Accumulator: Assign on both INIT and PROG
  wire [35:0] acc_sum;
  `ADD(36, acc_sum, acc_se[65:30], ptl_prod);

  flop #(66) acc_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~PROG_FINAL_STATE),
      .d(acc_c), .q(acc));

  wire [65:0] acc_init = {34'b0, op2};
  wire [65:0] acc_prog = {acc_sum, acc_se[29:0]};

  // Output sum for both PROG and FINAL
  mux #(66, 2) acc_c_mux (.sel(~INIT_STATE), .in({acc_prog, acc_init}), .out(acc_c));

endmodule
