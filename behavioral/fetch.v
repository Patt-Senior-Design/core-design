// instruction fetch unit
module fetch(
  input         clk,
  input         rst,

  // icache interface
  output        fetch_ic_req,
  output [31:2] fetch_ic_addr,
  output        fetch_ic_flush,
  input         icache_ready,
  input         icache_valid,
  input         icache_error,
  input [31:0]  icache_data,

  // brpred interface
  output        fetch_bp_req,
  output [31:2] fetch_bp_addr,
  input         brpred_bptaken,
  input [13:0]  brpred_bptag,
  input [29:0]  brpred_addr,

  // decode interface
  output        fetch_de_valid,
  output        fetch_de_error,
  output [29:0] fetch_de_addr,
  output [31:0] fetch_de_insn,
  output [13:0] fetch_de_bptag,
  output        fetch_de_bptaken,
  input         decode_stall,

  // rob interface
  input         rob_flush);



endmodule
