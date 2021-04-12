// one-hot shift register with load
module onehot_load #(
  parameter W = 16
  )(
  input          clk,
  input          rst,

  input          load,
  input [W-1:0]  load_val,

  input          shift,
  output [W-1:0] out);

  wire [W-1:0] out_next;
  mux #(W,2) out_next_mux(
    .sel(load),
    .in({load_val, {out[W-2:0],out[W-1]}}),
    .out(out_next));

  flop out_r[W-1:0](
    .clk(clk),
    .rst({{W-1{rst}},1'b0}),
    .set({{W-1{1'b0}},rst}),
    .enable(load | shift),
    .d(out_next),
    .q(out));

endmodule
