// RCA
module rca #(
  parameter W = 32
  )(
  input          sub,
  input [W-1:0]  a,
  input [W-1:0]  b,
  output [W-1:0] c);
  
  wire [W-1:0] op1 = a;
  // Negate for sub
  wire [W-1:0] op2 = b ^ {W{sub}};
  
  wire [W-1:0] g = op1 & op2;
  wire [W-1:0] p = op1 ^ op2;

  /*verilator lint_off UNOPTFLAT*/
  wire [W:0] carry;
  assign carry = {g | (p & carry[W-1:0]), sub};
  /*verilator lint_on UNOPTFLAT*/

  assign c = p ^ carry[W-1:0];

endmodule
