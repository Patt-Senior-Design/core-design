module mux #(
  parameter W = 32,
  parameter N = 16
  )(
  input [$clog2(N)-1:0] sel,
  input [(N*W)-1:0]     in,
  output [W-1:0]        out);

  wire [N-1:0] sel_onehot;
  decoder #($clog2(N)) decoder(
    .in(sel),
    .out(sel_onehot));

  premux #(W,N) premux(
    .sel(sel_onehot),
    .in(in),
    .out(out));

endmodule
