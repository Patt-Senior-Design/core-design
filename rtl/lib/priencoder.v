// Priority Encoder (Sklansky design): MSB of out is 1 if input is 0
module priencoder #(
  parameter BITS = 32,
  parameter SEARCH_BIT = 1
  )(
  input [BITS-1:0] in,
  output invalid,
  output  [$clog2(BITS)-1:0] out);

  wire p_invalid; // Unused
  wire [BITS-1:0] pvector;
  privector #(.BITS(BITS), .SEARCH_BIT(SEARCH_BIT)) ppf_vectree (
    .in (in),
    .invalid(p_invalid), // UNUSED
    .out (pvector));

  encoder #(.BITS(BITS)) oh_encode (
    .in (pvector),
    .invalid (invalid),
    .out (out));

endmodule
