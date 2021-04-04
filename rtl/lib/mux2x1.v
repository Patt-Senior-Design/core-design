module mux2x1 #(
  parameter W = 1
  )(
  input  sel,
  input  [W-1:0] in0,
  input  [W-1:0] in1,
  output [W-1:0] out);

  assign out = ({W{~sel}} & in0) | ({W{sel}} & in1);

endmodule
