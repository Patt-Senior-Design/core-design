// l2 cache
module l2(
  input             clk,
  input             rst,

  // icache interface
  input             icache_req,
  input [31:6]      icache_addr,
  output            l2_ic_ready,
  output            l2_ic_valid,
  output            l2_ic_error,
  output reg [63:0] l2_ic_rdata);

  wire req_beat;
  assign req_beat = icache_req & l2_ic_ready;

  reg [31:6] addr;
  always @(posedge clk)
    if(req_beat)
      addr <= icache_addr;

  integer cycle;
  always @(posedge clk)
    if(rst)
      cycle <= 0;
    else if(req_beat | cycle) begin
      cycle <= cycle + 1;
      if(cycle == 11)
        cycle <= 0;
    end

  assign l2_ic_ready = !cycle;
  assign l2_ic_valid = cycle >= 4;
  assign l2_ic_error = 0;

  reg [5:3] offset;
  always @(*)
    if(l2_ic_valid) begin
      offset = cycle - 4;
      top.mem_read(
        {icache_addr,offset,1'b0},
        l2_ic_rdata[31:0]);
      top.mem_read(
        {icache_addr,offset,1'b1},
        l2_ic_rdata[63:32]);
    end

endmodule
