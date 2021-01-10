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



endmodule
