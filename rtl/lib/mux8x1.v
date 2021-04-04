module mux8x1 #(
  parameter W = 1
  )(
  input  [2:0] sel,
  input  [W-1:0] in0,
  input  [W-1:0] in1,
  input  [W-1:0] in2,
  input  [W-1:0] in3,
  input  [W-1:0] in4,
  input  [W-1:0] in5,
  input  [W-1:0] in6,
  input  [W-1:0] in7,
  output [W-1:0] out);

  wire [W-1:0] tree0;
  wire [W-1:0] tree1;

  mux4x1 #(.W(W)) t0 (
    .sel (sel[1:0]),
    .in0 (in0),
    .in1 (in1),
    .in2 (in2),
    .in3 (in3),
    .out (tree0));

  mux4x1 #(.W(W)) t1 (
    .sel (sel[1:0]),
    .in0 (in4),
    .in1 (in5),
    .in2 (in6),
    .in3 (in7),
    .out (tree1));

  mux2x1 #(.W(W)) tf (
    .sel (sel[2]),
    .in0 (tree0),
    .in1 (tree1),
    .out (out));

endmodule
