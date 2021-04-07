// l2 request fifo
module l2fifo(
  input         clk,
  input         rst,

  // dcache interface (in)
  input         dcache_l2fifo_req,
  input [31:2]  dcache_l2fifo_addr,
  input         dcache_l2fifo_wen,
  input [3:0]   dcache_l2fifo_wmask,
  input [31:0]  dcache_l2fifo_wdata,
  output        l2fifo_dc_ready,

  // l2 interface (out)
  output        l2fifo_l2_req,
  output [31:2] l2fifo_l2_addr,
  output        l2fifo_l2_wen,
  output [3:0]  l2fifo_l2_wmask,
  output [31:0] l2fifo_l2_wdata,
  input         l2_l2fifo_ready);

  reg        req_valid;
  reg [31:2] req_addr;
  reg        req_wen;
  reg [3:0]  req_wmask;
  reg [31:0] req_wdata;
  always @(*) begin
    req_valid = dcache_l2fifo_req;
    req_addr = dcache_l2fifo_addr;
    req_wen = dcache_l2fifo_wen;
    req_wmask = dcache_l2fifo_wmask;
    req_wdata = dcache_l2fifo_wdata;
  end

  // 30+1+4+32-1 = 67
  wire [66:0] fifo_wr_data, fifo_rd_data;
  assign fifo_wr_data = {req_addr,req_wen,req_wmask,req_wdata};
  assign {l2fifo_l2_addr,l2fifo_l2_wen,l2fifo_l2_wmask,l2fifo_l2_wdata} = fifo_rd_data;

  wire fifo_wr_ready, fifo_rd_valid;
  fifo #(67,8) fifo(
    .clk(clk),
    .rst(rst),
    .wr_valid(req_valid),
    .wr_ready(fifo_wr_ready),
    .wr_data(fifo_wr_data),
    .rd_valid(fifo_rd_valid),
    .rd_ready(l2_l2fifo_ready),
    .rd_data(fifo_rd_data));

  assign l2fifo_dc_ready = fifo_wr_ready;
  assign l2fifo_l2_req = fifo_rd_valid;

endmodule
