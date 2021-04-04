module flop #(
  parameter width=1
  )(
  input clk,
  input rst,
  input enable, 
  input [width-1:0] d,
  output reg [width-1:0] q);

  always @(posedge clk) begin
    if (rst)
      q <= 0;
    else if (enable)
      q <= d;
  end

endmodule

