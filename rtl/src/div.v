// 32 x 32 divider
module div(
  input         clk,
  input         rst,

  input         req,
  input [1:0]   op,
  input [31:0]  op1,
  input [31:0]  op2,

  output        done,
  output [31:0] result,
  input         stall);

  // Divider state
  wire [4:0]  d_iter;
  wire [63:0] d_acc;
  wire [1:0]  d_state;

  // Dividend
  wire dvd_sgn = op1[31] & ~op[0];
  wire [31:0] op1_2c;
  `ADD(32, op1_2c, ~op1, 32'b1);
  wire [31:0] dvd;
  mux #(32, 2) dvd_mux (.sel(dvd_sgn), .in({op1_2c, op1}), .out(dvd));

  // Divisor
  wire dsor_sgn = op2[31] & ~op[0];
  wire [33:0] dsor_inv = {2'b00, op2};
  wire [33:0] dsor_2c;
  `ADD(34, dsor_2c, ~dsor_inv, 34'b1);

  wire [33:0] dsor;
  mux #(34, 2) dsor_mux (.sel(dsor_sgn), .in({{2'b11, op2}, dsor_2c}), .out(dsor));

  // Remainder (1)
  wire [33:0] ptl_rem = {1'b0,d_acc[63:31]};

  // Compare
  wire [33:0] cmp_res;
  `ADD (34, cmp_res, ptl_rem, dsor);

  // Remainder (2)
  wire [31:0] ptl_rem_n;
  mux #(32, 2) ptl_rem_n_mux (.sel(cmp_res[33]), .in({ptl_rem[31:0], cmp_res[31:0]}), 
    .out(ptl_rem_n));

  // Shift
  wire [31:0] d_shf = {d_acc[30:0],~cmp_res[33]};

  // Result
  wire [31:0] div_result;
  mux #(32, 2) div_result_mux (.sel(op[1]), .in(d_acc), .out(div_result));


  // State machine
  // INIT: 00, PROG: 01, PROG_FINAL: 10
  wire INIT_STATE = ~|d_state;
  wire PROG_STATE = d_state[0];
  wire PROG_FINAL_STATE = d_state[1];

  // Outputs
  wire invert_result = dvd_sgn ^ (~op[1] & dsor_sgn);
  wire [31:0] div_result_2c;
  `ADD(32, div_result_2c, ~div_result, 1);

  assign done = PROG_FINAL_STATE;
  mux #(32, 2) result_mux (.sel(invert_result), .in({div_result_2c, div_result}), .out(result));

  
  // State transitions
  wire [4:0]  d_iter_c;
  wire [63:0] d_acc_c;
  wire [1:0]  d_next_state;
  
  // iter == 1
  wire iter_done = ~|d_iter[4:1] & d_iter[0];
  wire d_state_enable = (INIT_STATE & req) | (PROG_STATE & iter_done) | (PROG_FINAL_STATE & ~stall);
  // INIT = 2'b00 so assert rst
  flop #(2) d_state_flop (.clk(clk), .rst(rst), .set(1'b0), .enable(d_state_enable),
      .d(d_next_state), .q(d_state));
  assign d_next_state = {PROG_STATE, INIT_STATE};

  // iter == 0 on INIT, assign during PROG
  flop #(5) d_iter_flop (.clk(clk), .rst(INIT_STATE), .set(1'b0), .enable(PROG_STATE),
      .d(d_iter_c), .q(d_iter));
  `SUB(5, d_iter_c, d_iter, 5'h1);

  // Accumulator: Assign on both INIT and PROG
  flop #(64) d_acc_flop (.clk(clk), .rst(1'b0), .set(1'b0), .enable(~PROG_FINAL_STATE),
      .d(d_acc_c), .q(d_acc));

  wire [63:0] d_acc_init = {32'b0, dvd};
  wire [63:0] d_acc_prog = {ptl_rem_n, d_shf};

  // Output sum for both PROG and FINAL
  mux #(64, 2) d_acc_c_mux (.sel(~INIT_STATE), .in({d_acc_prog, d_acc_init}), .out(d_acc_c));

endmodule
