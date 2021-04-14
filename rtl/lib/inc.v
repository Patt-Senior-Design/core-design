// half adder incrementer
module inc #(
    parameter W = 32
) (
    input sub,
    input [W-1:0] in,
    output [W-1:0] out
);

  wire [W:0] carry;
  assign carry[0] = 1;

  genvar i;
  generate
    for (i = 0; i < W; i = i + 1) begin : inc
      assign out[i] = in[i] ^ carry[i];
      assign carry[i+1] = in[i] & carry[i];
    end
  endgenerate

endmodule
