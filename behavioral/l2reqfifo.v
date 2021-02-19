// l2 request fifo
module l2reqfifo(
  input         clk,
  input         rst,

  // icache interface
  input         icache_req,
  input [31:6]  icache_addr,
  output        l2_ic_ready,

  // dcache interface
  input         dcache_l2_req,
  input [31:2]  dcache_l2_addr,
  input         dcache_l2_wen,
  input [3:0]   dcache_l2_wmask,
  input [31:0]  dcache_l2_wdata,
  output        l2_dc_ready,

  // l2tag interface
  output        l2reqfifo_valid,
  output        l2reqfifo_dcache,
  output [31:2] l2reqfifo_addr,
  output        l2reqfifo_wen,
  output [3:0]  l2reqfifo_wmask,
  output [31:0] l2reqfifo_wdata,
  input         l2tag_l2reqfifo_ready);

  reg        req_valid;
  reg [31:2] req_addr;
  reg        req_wen;
  reg [3:0]  req_wmask;
  reg [31:0] req_wdata;
  always @(*) begin
    req_valid = icache_req | dcache_l2_req;
    req_wmask = dcache_l2_wmask;
    req_wdata = dcache_l2_wdata;
    if(dcache_l2_req) begin
      req_addr = dcache_l2_addr;
      req_wen = dcache_l2_wen;
    end else begin
      req_addr = {icache_addr,4'b0};
      req_wen = 0;
    end
  end

  // 1+30+1+4+32-1 = 68
  wire [67:0] reqfifo_wr_data, reqfifo_rd_data;
  assign reqfifo_wr_data = {dcache_l2_req,req_addr,req_wen,req_wmask,req_wdata};
  assign {l2reqfifo_dcache,l2reqfifo_addr,l2reqfifo_wen,l2reqfifo_wmask,l2reqfifo_wdata} = reqfifo_rd_data;

  wire reqfifo_wr_ready, reqfifo_rd_valid;
  fifo #(68,8) reqfifo(
    .clk(clk),
    .rst(rst),
    .wr_valid(req_valid),
    .wr_ready(reqfifo_wr_ready),
    .wr_data(reqfifo_wr_data),
    .rd_valid(l2reqfifo_valid),
    .rd_ready(l2tag_l2reqfifo_ready),
    .rd_data(reqfifo_rd_data));

  assign l2_ic_ready = reqfifo_wr_ready & ~dcache_l2_req;
  assign l2_dc_ready = reqfifo_wr_ready;

endmodule
