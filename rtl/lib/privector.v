// Priority Encoder (Sklansky design): MSB of out is 1 if input is 0
/* verilator lint_off WIDTH */
/* verilator lint_off UNOPTFLAT */
module privector #(
  parameter BITS = 32,
  parameter SEARCH_BIT = 1
  )(
  input [BITS-1:0] in,
  output invalid,
  output  [BITS-1:0] out);

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
      localparam base_prop = BITS - (1 << i); 
      localparam bit_mask = 1 << i;
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
 
  assign out = partial_out[$clog2(BITS)];
  assign invalid = ~|partial_out[0];

endmodule
/* verilator lint_on UNOPTFLAT */
/* verilator lint_on WIDTH */
