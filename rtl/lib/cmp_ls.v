// CMP_LS
module cmp_ls #(
  parameter W = 32
  )(
  input          sgn,
  input [W-1:0]  a,
  input [W-1:0]  b,
  output [W-1:0] out);
  
  wire [W-1:0] found;
  wire [W-1:0] cmp_res;

  assign found[W-1] = a[W-1] ^ b[W-1];
  assign cmp_res[W-1] = ~a[W-1] & b[W-1];

  genvar i;
  generate
    for (i = W-2; i >= 0; i=i-1) begin : cmp_gen
      assign found[i] = found[i+1] | (a[i] ^ b[i]);
      mux #(1, 2) cmp_res_mux (.sel(found[i+1]), .in({cmp_res[i+1], ~a[i] & b[i]}), .out(cmp_res[i]));
    end
  endgenerate
 
  wire opp_sgn = found[W-1];

  assign out = {31'b0, cmp_res[0] ^ (sgn & opp_sgn & ~(a == b))};

endmodule
