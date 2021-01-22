// priority arbiter
module priarb #(
  parameter WIDTH = 16
  )(
  input [WIDTH-1:0]      req,
  output reg             grant_valid,
  output reg [WIDTH-1:0] grant);

  integer i;
  always @(*) begin
    grant_valid = 0;
    grant = 0;
    for(i = 0; i < WIDTH; i=i+1)
      if(req[i]) begin
        grant_valid = 1;
        grant[i] = 1;
        i = WIDTH;
      end
  end

endmodule
