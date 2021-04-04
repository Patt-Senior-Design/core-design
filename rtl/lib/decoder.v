module decoder #(
  parameter BITS = 1
  )(
  input  [BITS-1:0]      in,
  output [(1<<BITS)-1:0] out);

  genvar i;
  generate
    for (i = 0; i < (1<<BITS); i=i+1) begin : dec
      assign out[i] = (in == i);
    end
  endgenerate

endmodule
