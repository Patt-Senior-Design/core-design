module test_cache;
  reg clk;
  reg rst;
  
  reg req;
  reg [31:0] addr;
  wire ready;
  wire fs;
  wire [63:0] rdata;
  wire rbuf_empty;

  bfs_cache b(
      .clk (clk),
      .rst (rst),
      .bfs_dc_req(req & ready),
      .bfs_dc_addr(addr),
      .dc_ready(ready),
      .dc_rbuf_empty(rbuf_empty),
      .dc_fs(fs),
      .dc_rdata(rdata));
  
  always #5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
    $dumplimit(32*1024*1024);
    clk = 0;
    rst = 1;
    #30;
    rst = 0;
    req = 1;
    addr = 12'h000;
    #30;
    req = 0;
    #70;
    req = 1;
    addr = 12'h9C0;
    #100;
    addr = 12'h380;
    #100;
    addr = 12'h9C0;
    #100;
  end
endmodule
