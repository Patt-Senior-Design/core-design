// priority arbiter
module priarb #(
  parameter WIDTH = 16
  )(
  input [WIDTH-1:0]      req,
  output reg             grant_valid,
  output reg [WIDTH-1:0] grant);

  /*verilator lint_off UNOPTFLAT*/
  wire [WIDTH-1:0] therm;
  assign therm = {req[WIDTH-2:0],1'b0} | {therm[WIDTH-2:0],1'b0};
  /*verilator lint_on UNOPTFLAT*/

  assign grant_valid = |req;
  assign grant = req & ~therm;

endmodule
