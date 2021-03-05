module test_outq;
  reg clk;
  reg rst;
  
  reg[1:0] en_req;
  reg[63:0] wdata;
  reg de_req;
  wire[63:0] rdata;
  wire[63:0] tdata;
  wire rfilled;
  wire full;
  wire empty;

  queue_out #(8) b(
    .clk(clk),
    .bfs_rst(rst),
    .enqueue_req(en_req),
    .wdata_in(wdata),
    .dequeue_req(de_req),
    .rdata_out(rdata),
    .tail_data(tdata),
    .rdata_filled(rfilled),
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
    #20
    rst = 0;
    wdata = {32'b0, 32'hDEADBEEF}; // FROM NODE
    #10;
    rst = 0;
    de_req = 0;
    en_req = 2'b11;
    wdata = {32'hFDFDFDFD, 32'hCECECECE};
    #10;
    en_req = 2'b00;
    #20;
    en_req = 2'b01;
    wdata = {32'b0, 32'hBADADDED};
    #30;
    en_req = 2'b11;
    #10;
    en_req = 2'b01;
    wdata = {32'hFFFFFFFF, 32'hAAAAAAAA};
    #10;
    en_req = 2'b00;
    de_req = 1;
    #30;
    de_req = 0;
    #20;
    de_req = 1;
    #100;
  end
endmodule
