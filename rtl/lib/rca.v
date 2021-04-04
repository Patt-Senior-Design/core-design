// RCA
module rca #(
  parameter W = 32
  )(
  input sub,
  input [W-1:0] a,
  input [W-1:0] b,
  output [W-1:0] c);
  
  wire [W-1:0] op1 = a;
  // Negate for sub
  wire [W-1:0] op2 = b ^ {W{sub}};
  
  wire [W:0] carry;
  assign carry[0] = sub;

  wire [W-1:0] g;
  wire [W-1:0] p;

  genvar i;
  generate
    for (i = 0; i < W; i = i+1) begin : rca
      assign g[i] = op1[i] & op2[i];
      assign p[i] = op1[i] ^ op2[i];

      assign c[i] = p[i] ^ carry[i];
      assign carry[i+1] = g[i] | (p[i] & carry[i]);
    end
  endgenerate
  
endmodule
