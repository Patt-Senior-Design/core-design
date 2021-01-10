// RISC-V instruction decoder
module decode(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_de_valid,
  input         fetch_de_error,
  input [31:2]  fetch_de_addr,
  input [31:0]  fetch_de_insn,
  input [13:0]  fetch_de_bptag,
  input         fetch_de_bptaken,
  output        decode_stall,

  // common rob/rename signals
  output [31:2] decode_addr,
  output [5:0]  decode_rd,

  // rob interface
  output        decode_rob_valid,
  output        decode_error,
  output [5:0]  decode_retop,
  output [13:0] decode_bptag,
  output        decode_bptaken,
  input         rob_flush,
  input         rob_full,
  input [7:0]   rob_robid,

  // rename interface
  output        decode_rename_valid,
  output [4:0]  decode_op,
  output [7:0]  decode_robid,
  output        decode_uses_rs1,
  output        decode_uses_rs2,
  output        decode_uses_imm,
  output        decode_uses_memory,
  output        decode_store,
  output        decode_csr_access,
  output [4:0]  decode_rs1,
  output [4:0]  decode_rs2,
  output [31:0] decode_imm);



endmodule
