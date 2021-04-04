module mux16x1 #(
  parameter W = 1
  )(
  input  [3:0] sel,
  input  [W-1:0] in0,
  input  [W-1:0] in1,
  input  [W-1:0] in2,
  input  [W-1:0] in3,
  input  [W-1:0] in4,
  input  [W-1:0] in5,
  input  [W-1:0] in6,
  input  [W-1:0] in7,
  input  [W-1:0] in8,
  input  [W-1:0] in9,
  input  [W-1:0] in10,
  input  [W-1:0] in11,
  input  [W-1:0] in12,
  input  [W-1:0] in13,
  input  [W-1:0] in14,
  input  [W-1:0] in15,
  output [W-1:0] out);

  wire [W-1:0] tree0;
  wire [W-1:0] tree1;

  mux8x1 #(.W(W)) t0 (
    .sel (sel[2:0]),
    .in0 (in0),
    .in1 (in1),
    .in2 (in2),
    .in3 (in3),
    .in4 (in4),
    .in5 (in5),
    .in6 (in6),
    .in7 (in7),
    .out (tree0));

  mux8x1 #(.W(W)) t1 (
    .sel (sel[2:0]),
    .in0 (in8),
    .in1 (in9),
    .in2 (in10),
    .in3 (in11),
    .in4 (in12),
    .in5 (in13),
    .in6 (in14),
    .in7 (in15),
    .out (tree1));

  mux2x1 #(.W(W)) tf (
    .sel (sel[3]),
    .in0 (tree0),
    .in1 (tree1),
    .out (out));

endmodule
