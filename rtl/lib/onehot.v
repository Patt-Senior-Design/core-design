// one-hot shift register
module onehot #(
  parameter W = 16
  )(
  input          clk,
  input          rst,

  input          shift,
  output [W-1:0] out);

  flop out_r[W-1:0](
    .clk(clk),
    .rst({{W-1{rst}},1'b0}),
    .set({{W-1{1'b0}},rst}),
    .enable(shift),
    .d({out[W-2:0],out[W-1]}),
    .q(out));

endmodule
