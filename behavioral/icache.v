// instruction cache
module icache(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_ic_req,
  input [31:2]  fetch_ic_addr,
  input         fetch_ic_flush,
  output        icache_ready,
  output        icache_valid,
  output        icache_error,
  output [31:0] icache_data);

  localparam STDERR = 32'h80000002;

  reg        req_s0, req_s1;
  reg [31:2] addr_s0;
  reg [31:0] rdata_s1;
  always @(posedge clk)
    if(rst | fetch_ic_flush) begin
      req_s0 <= 0;
      req_s1 <= 0;
    end else begin
      req_s0 <= fetch_ic_req;
      addr_s0 <= fetch_ic_addr;

      req_s1 <= req_s0;
      if(req_s0)
        top.mem_read(addr_s0, rdata_s1);
    end

  assign icache_ready = 1;
  assign icache_valid = req_s1;
  assign icache_error = 0;
  assign icache_data = rdata_s1;

endmodule
