module test_q;
  reg clk;
  reg rst;
  
  /*reg req;
  reg [31:0] addr;
  wire ready;
  wire fs;
  wire [63:0] rdata;

  bfs_cache b(
      .clk (clk),
      .rst (rst),
      .bfs_req(req & ready),
      .bfs_req_addr(addr),
      .cache_ready(ready),
      .cache_fs(fs),
      .cache_rdata(rdata));
  */
  reg[1:0] en_req;
  reg[63:0] wdata;
  reg de_req;
  wire[31:0] rdata;
  wire full;
  wire empty;

  bfs_queue b(
    .clk(clk),
    .bfs_rst(rst),
    .enqueue_req(en_req),
    .wdata_in(wdata),
    .dequeue_req(de_req),
    .rdata_out(rdata),
    .queue_full(full),
    .queue_empty(empty));

  always #5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
    $dumplimit(32*1024*1024);
    clk = 0;
    rst = 1;
    en_req = 2'b01;
    wdata = {32'b0, 32'hDEADBEEF}; // FROM NODE
    #30;
    rst = 0;
    de_req = 0;
    en_req = 2'b11;
    wdata = {32'hFDFDFDFD, 32'hCECECECE};
    #20;
    en_req = 2'b00;
    #10;
    en_req = 2'b01;
    #50;
    en_req = 2'b11;
    #50;
    en_req = 2'b00;
    de_req = 1;
    #30;
    de_req = 0;
    #20;
    de_req = 1;
  end
endmodule
