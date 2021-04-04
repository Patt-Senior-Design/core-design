module mux4x1 #(
  parameter W = 1
  )(
  input  [1:0] sel,
  input  [W-1:0] in0,
  input  [W-1:0] in1,
  input  [W-1:0] in2,
  input  [W-1:0] in3,
  output [W-1:0] out);

  wire [W-1:0] tree0;
  wire [W-1:0] tree1;

  mux2x1 #(.W(W)) t0 (
    .sel (sel[0]),
    .in0 (in0),
    .in1 (in1),
    .out (tree0));

  mux2x1 #(.W(W)) t1 (
    .sel (sel[0]),
    .in0 (in2),
    .in1 (in3),
    .out (tree1));

  mux2x1 #(.W(W)) tf (
    .sel (sel[1]),
    .in0 (tree0),
    .in1 (tree1),
    .out (out));

endmodule
