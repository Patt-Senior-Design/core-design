module flop #(parameter width=1)(input wire clk, input wire enable, input wire [width-1:0] d, output reg [width-1:0] q);

always @(posedge clk)
  if (enable)
    q <= d;

endmodule

