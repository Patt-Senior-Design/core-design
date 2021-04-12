module encoder #(
  parameter BITS = 1
  )(
  input [BITS-1:0]          in,
  output                    invalid,
  output [$clog2(BITS)-1:0] out);

  assign invalid = ~|in;

  /*verilator lint_off WIDTH*/
  wire [(BITS>>1)-1:0] encode_bits [$clog2(BITS)-1:0];
  genvar i;
  genvar k;
  generate
    for (i = 0; i < BITS; i=i+1) begin : enc_outer
      genvar j;
      for (j = 0; j < $clog2(BITS); j=j+1) begin : enc_inner
        localparam k = ((i >> (j+1)) << j) | (i & ((1 << j)-1));
        if ((i >> j) & 1) 
          assign encode_bits[j][k] = in[i];
      end
    end
    for (i = 0; i < $clog2(BITS); i=i+1) begin : enc_assign
      assign out[i] = |encode_bits[i];
    end
  endgenerate
  /*verilator lint_on WIDTH*/

endmodule
