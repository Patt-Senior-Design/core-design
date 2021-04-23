module sram #(
  parameter W = 1,
  parameter N = 14
  )(
  input clk,
  input rst,
  input ren,
  input [N-1:0] raddr,
  output reg [W-1:0] rdata,
  input wen,
  input [N-1:0] waddr,
  input [W-1:0] wdata);
  
  reg [W-1:0] memory [(1<<N)-1:0];

  // simulation only
  integer i;
  initial
    for(i = 0; i < (1<<N); i=i+1)
      memory[i] = 0;

  always @(posedge clk) begin
    if (ren)
      rdata <= memory[raddr];
    if (wen)
      memory[waddr] <= wdata;
  end

endmodule

