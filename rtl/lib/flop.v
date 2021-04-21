module flop #(
  parameter width=1
  )(
  input clk,
  input rst,
  input set,
  input enable, 
  input [width-1:0] d,
  output reg [width-1:0] q);

  always @(posedge clk) begin
    if (enable)
      q <= d;
    if (set)
      q <= {width{1'b1}};
    if (rst)
      q <= 0;
  end

endmodule

