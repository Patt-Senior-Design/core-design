module top();

  reg clk;
  reg rst;
  cpu cpu(
    .clk(clk),
    .rst(rst));

  always
    #5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;

    clk = 0;
    rst = 1;
    #100;
    rst = 0;
    #1000;
    $finish;
  end

endmodule
