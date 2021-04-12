// mux with pre-decoded select inputs
module premux #(
  parameter W = 32,
  parameter N = 16
  )(
  input [N-1:0]     sel,
  input [(N*W)-1:0] in,
  output [W-1:0]    out);

  /*verilator lint_off UNOPTFLAT*/
  wire [W-1:0] steps [0:N];

  genvar i;
  generate
    for(i = 0; i < N; i=i+1)
      assign steps[i+1] = steps[i] | ({W{sel[i]}} & in[i*W+:W]);
  endgenerate
  /*verilator lint_on UNOPTFLAT*/

  assign steps[0] = 0;
  assign out = steps[N];

endmodule
