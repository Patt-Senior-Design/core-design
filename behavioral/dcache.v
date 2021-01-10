// data cache
module dcache(
  input         clk,
  input         rst,

  // lsq interface
  input         lsq_dc_req,
  input [3:0]   lsq_dc_op,
  input [4:0]   lsq_dc_lsqid,
  input [31:0]  lsq_dc_wdata,
  input         lsq_dc_flush,
  output        dcache_ready,
  output        dcache_valid,
  output        dcache_error,
  output [4:0]  dcache_lsqid,
  output [31:0] dcache_rdata);



endmodule
