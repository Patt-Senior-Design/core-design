// l2 cache
module l2(
  input         clk,
  input         rst,

  // icache interface
  input         icache_req,
  input [31:6]  icache_addr,
  output        l2_ic_ready,
  output        l2_ic_valid,
  output        l2_ic_error,
  output [63:0] l2_ic_rdata,

  // dcache interface
  input         dcache_l2_ready,
  input         dcache_l2_req,
  input [31:2]  dcache_l2_addr,
  input         dcache_l2_wen,
  input [3:0]   dcache_l2_wmask,
  input [31:0]  dcache_l2_wdata,
  output        l2_dc_ready,
  output        l2_dc_valid,
  output        l2_dc_error,
  output [63:0] l2_dc_rdata,
  output        l2_dc_invalidate,
  output [31:6] l2_dc_iaddr);

  // request arbitration
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

  reg [7:0]  reqbuf_dcache;
  reg [31:2] reqbuf_addr [0:7];
  reg [7:0]  reqbuf_wen;
  reg [3:0]  reqbuf_wmask [0:7];
  reg [31:0] reqbuf_wdata [0:7];

  reg [2:0]  reqbuf_head, reqbuf_tail;
  reg        reqbuf_head_pol, reqbuf_tail_pol;

  reg        s1_valid;
  reg        s1_dcache;
  reg [31:2] s1_addr;
  reg        s1_wen;
  reg [3:0]  s1_wmask;
  reg [31:0] s1_wdata;
  reg [63:0] s1_rdata;

  integer    s1_cycle;

  wire reqbuf_empty, reqbuf_full;
  assign reqbuf_empty = (reqbuf_head == reqbuf_tail) & (reqbuf_head_pol == reqbuf_tail_pol);
  assign reqbuf_full  = (reqbuf_head == reqbuf_tail) & (reqbuf_head_pol != reqbuf_tail_pol);

  wire s1_stall;
  assign s1_stall = s1_valid & ~s1_wen & ((s1_cycle < 11) | ~dcache_l2_ready);

  wire reqbuf_in_beat, reqbuf_out_beat;
  assign reqbuf_in_beat = req_valid & ~reqbuf_full;
  assign reqbuf_out_beat = ~s1_stall & ~reqbuf_empty;

  wire s1_read_valid;
  assign s1_read_valid = (s1_cycle >= 4);

  wire s1_inc_cycle;
  assign s1_inc_cycle = ~s1_read_valid | dcache_l2_ready;

  // icache interface
  assign l2_ic_ready = ~reqbuf_full & ~dcache_l2_req;
  assign l2_ic_valid = s1_read_valid & ~s1_dcache;
  assign l2_ic_error = 0;
  assign l2_ic_rdata = s1_rdata;

  // dcache interface
  assign l2_dc_ready = ~reqbuf_full;
  assign l2_dc_valid = s1_read_valid & s1_dcache;
  assign l2_dc_error = 0;
  assign l2_dc_rdata = s1_rdata;
  assign l2_dc_invalidate = 0;
  assign l2_dc_iaddr = 0;

  // reqbuf_head
  always @(posedge clk)
    if(rst) begin
      reqbuf_head <= 0;
      reqbuf_head_pol <= 0;
    end else if(reqbuf_out_beat)
      {reqbuf_head_pol,reqbuf_head} <= {reqbuf_head_pol,reqbuf_head} + 1;

  // reqbuf_tail
  always @(posedge clk)
    if(rst) begin
      reqbuf_tail <= 0;
      reqbuf_tail_pol <= 0;
    end else if(reqbuf_in_beat)
      {reqbuf_tail_pol,reqbuf_tail} <= {reqbuf_tail_pol,reqbuf_tail} + 1;

  // reqbuf write
  always @(posedge clk)
    if(reqbuf_in_beat) begin
      reqbuf_dcache[reqbuf_tail] <= dcache_l2_req;
      reqbuf_addr[reqbuf_tail] <= req_addr;
      reqbuf_wen[reqbuf_tail] <= req_wen;
      reqbuf_wmask[reqbuf_tail] <= req_wmask;
      reqbuf_wdata[reqbuf_tail] <= req_wdata;
    end

  // reqbuf read
  always @(posedge clk)
    if(rst)
      s1_valid <= 0;
    else if(~s1_stall) begin
      s1_valid <= ~reqbuf_empty;
      if(~reqbuf_empty) begin
        s1_dcache <= reqbuf_dcache[reqbuf_head];
        s1_addr <= reqbuf_addr[reqbuf_head];
        s1_wen <= reqbuf_wen[reqbuf_head];
        s1_wmask <= reqbuf_wmask[reqbuf_head];
        s1_wdata <= reqbuf_wdata[reqbuf_head];
      end
    end

  // s1_cycle
  always @(posedge clk)
    if(rst | ~s1_stall)
      s1_cycle <= 0;
    else if(s1_inc_cycle)
      s1_cycle <= s1_cycle + 1;

  // read command
  reg [5:3] offset;
  always @(*)
    if(s1_read_valid) begin
      offset = s1_cycle - 4;
      top.mem_read(
        {s1_addr[31:6],offset,1'b0},
        s1_rdata[31:0]);
      top.mem_read(
        {s1_addr[31:6],offset,1'b1},
        s1_rdata[63:32]);
    end

  // write command
  always @(posedge clk)
    if(s1_valid & s1_wen)
      top.mem_write(
        s1_addr,
        s1_wmask,
        s1_wdata);

endmodule
