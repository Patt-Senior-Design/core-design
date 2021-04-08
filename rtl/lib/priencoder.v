// Priority Encoder (Sklansky design): MSB of out is 1 if input is 0
module priencoder #(
  parameter BITS = 32,
  parameter SEARCH_BIT = 1
  )(
  input [BITS-1:0] in,
  output invalid,
  output  [$clog2(BITS)-1:0] out,
  output  [BITS-1:0] ptl_out);

  wire [BITS-1:0] partial_out [$clog2(BITS):0];
  wire [BITS-1:0] found [$clog2(BITS):0];

  genvar i;     // out = prop' . bit
  generate
    if (SEARCH_BIT) begin
      assign partial_out[0] = in;
      assign found[0] = in;
    end else begin
      assign partial_out[0] = ~in;
      assign found[0] = ~in;
    end
  endgenerate

  localparam B = BITS - 1;
  generate
    for (i = 0; i < $clog2(BITS); i = i + 1) begin : prienc_outer
      genvar j;
      localparam base_prop = BITS - (1 << i); // 15
      localparam bit_mask = 1 << i; // 1
      for (j = 0; j < BITS; j = j + 1) begin : prienc_inner
        localparam prop_idx = ((j >> i) << i) | bit_mask; 
        if (~j & bit_mask) begin
          // Merge Cell
          assign partial_out[i+1][B-j] = ~found[i][B-prop_idx] & partial_out[i][B-j];
          assign found[i+1][B-j] = found[i][B-prop_idx] | found[i][B-j];
        end else begin 
          // Pass-through cell
          assign partial_out[i+1][B-j] = partial_out[i][B-j];
          assign found[i+1][B-j] = found[i][B-j];
        end
      end

    end
  endgenerate
 
  /*integer m;
  initial begin
    #1;
    for (m = 0; m < BITS + 1; m=m+1) begin
      $display("Partial 0:%4h, 1:%4h, 2:%4h, 3:%4h, 4:%4h", partial_out[0], partial_out[1], partial_out[2], partial_out[3], partial_out[4]);
      #5;
    end
  end*/

  assign ptl_out = partial_out[$clog2(BITS)];

  encoder #(.BITS(BITS)) oh_encode (
    .in (partial_out[$clog2(BITS)]),
    .invalid (invalid),
    .out (out));

endmodule
