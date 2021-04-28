// Single Cycle ALU operations
module alu_simple(
  // exec unit interface
  input [4:0]       op,
  input [31:0]      op1,
  input [31:0]      op2,
  output [31:0] sc_result);

  wire [31:0] p_vector;
  wire p_vec_zero;
  privector #(32, 1) p_vector_prippf (.in(op1 & ~op2), .invalid(p_vec_zero),
    .out(p_vector));

  wire [4:0] p_index;
  encoder #(32) p_index_enc (.in(p_vector), .invalid(), .out(p_index));
  
  
  wire [31:0] add_res;
  rca #(32) adder(.sub(op[3]), .a(op1), .b(op2), .c(add_res)); // ADD,SUB
  
  wire [31:0] sll_res;
  shf #(32, 0) lshf(.sgn(1'b0), .a(op1), .b(op2[4:0]), .c(sll_res)); // SLL
  
  wire [31:0] slt_res;
  cmp_ls #(32) slt (.sgn(1'b1), .a(op1), .b(op2), .out(slt_res));
  
  wire [31:0] sltu_res;
  cmp_ls #(32) sltu(.sgn(1'b0), .a(op1), .b(op2), .out(sltu_res));
  
  wire [31:0] xorseq_res;
  mux #(32, 2) xor_mux (.sel(op[3]), .in({{31'b0,op1 == op2}, op1^op2}), .out(xorseq_res)); // XOR, SEQ

  wire [31:0] srl_res;
  shf #(32, 1) rshf(.sgn(op[3]), .a(op1), .b(op2[4:0]), .c(srl_res));
  
  wire [31:0] or_res = op1 | op2;
  wire [31:0] and_res = op1 & op2;

  wire [31:0] basic_res;
  mux #(32, 8) basic_alu_mux (.sel(op[2:0]), 
    .in({and_res, or_res, srl_res, xorseq_res, sltu_res, slt_res, sll_res, add_res}),
    .out(basic_res));

  wire [31:0] pfind_res = {p_vec_zero, 26'b0, p_index};
  wire [31:0] pclear_res = op1 ^ p_vector;
  wire [31:0] prio_res;
  mux #(32, 2) prio_mux (.sel(op[0]), .in({pclear_res, pfind_res}), .out(prio_res));

  mux #(32, 2) sc_result_mux (.sel(op[4]), .in({prio_res, basic_res}), .out(sc_result));

endmodule
