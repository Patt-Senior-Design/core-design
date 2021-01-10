// register rename and instruction dispatch unit
module rename(
  input         clk,
  input         rst,

  // decode interface
  input         decode_rename_valid,
  input [31:0]  decode_addr,
  input [4:0]   decode_op,
  input [7:0]   decode_robid,
  input [5:0]   decode_rd,
  input         decode_uses_rs1,
  input         decode_uses_rs2,
  input         decode_uses_imm,
  input         decode_uses_memory,
  input         decode_store,
  input         decode_csr_access,
  input [4:0]   decode_rs1,
  input [4:0]   decode_rs2,
  input [31:0]  decode_imm
  output        rename_stall,

  // rat interface
  output        rename_valid,
  output [5:0]  rename_rd,
  output [7:0]  rename_robid,
  output [4:0]  rename_rs1,
  output [4:0]  rename_rs2,
  input         rat_rs1_valid,
  input [31:0]  rat_rs1_tagval,
  input         rat_rs2_valid,
  input [31:0]  rat_rs2_tagval,

  // exers/lsq/csr interface
  output        rename_exers_write,
  output        rename_lsq_write,
  output        rename_csr_write,
  output [4:0]  rename_op,
  output [7:0]  rename_robid,
  output [5:0]  rename_rd,
  output        rename_op1ready,
  output [31:0] rename_op1,
  output        rename_op2ready,
  output [31:0] rename_op2,
  output [31:0] rename_imm,
  input         exers_stall,
  input         lsq_stall,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [7:0]   wb_robid,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush);



endmodule
