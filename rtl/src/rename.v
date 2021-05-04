// register rename and instruction dispatch unit
module rename(
  input            clk,
  input            rst,

  // decode interface
  input            decode_rename_valid,
  input [31:2]     decode_addr,
  input [4:0]      decode_rsop,
  input [6:0]      decode_robid,
  input [5:0]      decode_rd,
  input            decode_uses_rs1,
  input            decode_uses_rs2,
  input            decode_uses_imm,
  input            decode_uses_memory,
  input            decode_uses_pc,
  input            decode_csr_access,
  input            decode_forward,
  input            decode_inhibit,
  input [31:2]     decode_target,
  input [4:0]      decode_rs1,
  input [4:0]      decode_rs2,
  input [31:0]     decode_imm,
  output           rename_stall,

  // rat interface
  output [4:0]     rename_rs1,
  output [4:0]     rename_rs2,
  output           rename_alloc,
  input            rat_rs1_valid,
  input [31:0]     rat_rs1_tagval,
  input            rat_rs2_valid,
  input [31:0]     rat_rs2_tagval,

  // common rat/dispatch/wb signals
  output [5:0]      rename_rd,
  output [6:0]      rename_robid,

  // exers/lsq/csr interface
  output           rename_exers_write,
  output           rename_lsq_write,
  output           rename_csr_write,
  output [4:0]     rename_op,
  output           rename_op1ready,
  output [31:0]    rename_op1,
  output           rename_op2ready,
  output [31:0]    rename_op2,
  output [31:0]    rename_imm,
  input            exers_stall,
  input            lsq_stall,
  input            csr_stall,

  // wb interface
  output rename_wb_valid,
  output [31:2] rename_wb_result,

  // rob interface
  input             rob_flush,
  input             rob_rename_ishead,
  output            rename_inhibit);

  // decode signals
  wire valid;
  wire stall;
  wire [6:0] robid;
  wire [31:0] addr;
  wire [4:0] op;
  wire [5:0] rd;
  wire uses_rs1;
  wire uses_rs2;
  wire uses_imm;
  wire uses_memory;
  wire uses_pc;
  wire csr_access;
  wire forward;
  wire inhibit;
  wire [31:2] result;
  wire [4:0] rs1;
  wire [4:0] rs2;
  wire [31:0] imm;

  flop valid_flop       (clk, rst | rob_flush, 0, !rename_stall, decode_rename_valid, valid);
  flop #(7) robid_flop  (clk, 0, 0, !rename_stall, decode_robid, robid);
  flop #(32) addr_flop  (clk, 0, 0, !rename_stall, {decode_addr, 2'b00}, addr);
  flop #(5) op_flop     (clk, 0, 0, !rename_stall, decode_rsop, op);
  flop #(6) rd_flop     (clk, 0, 0, !rename_stall, decode_rd, rd);
  flop uses_rs1_flop    (clk, 0, 0, !rename_stall, decode_uses_rs1, uses_rs1);
  flop uses_rs2_flop    (clk, 0, 0, !rename_stall, decode_uses_rs2, uses_rs2);
  flop uses_imm_flop    (clk, 0, 0, !rename_stall, decode_uses_imm, uses_imm);
  flop uses_memory_flop (clk, 0, 0, !rename_stall, decode_uses_memory, uses_memory);
  flop uses_pc_flop     (clk, 0, 0, !rename_stall, decode_uses_pc, uses_pc);
  flop csr_access_flop  (clk, 0, 0, !rename_stall, decode_csr_access, csr_access);
  flop forward_flop     (clk, 0, 0, !rename_stall, decode_forward, forward);
  flop inhibit_flop     (clk, 0, 0, !rename_stall, decode_inhibit, inhibit);
  flop #(30) result_flop(clk, 0, 0, !rename_stall, decode_target, result);
  flop #(5) rs1_flop    (clk, 0, 0, !rename_stall, decode_rs1, rs1);
  flop #(5) rs2_flop    (clk, 0, 0, !rename_stall, decode_rs2, rs2);
  flop #(32) imm_flop   (clk, 0, 0, !rename_stall, decode_imm, imm);

  // reservation stations seq
  assign rename_lsq_write = valid & uses_memory;
  assign rename_exers_write = valid & (~uses_memory) & (~csr_access);
  assign rename_csr_write = valid & csr_access & rob_rename_ishead & ~rob_flush;
  assign rename_op = op;
  assign rename_robid = robid;
  assign rename_rd = rd | {forward, 5'b0}; // inhibit uses_rd if forwarding

  wire [31:0] op1_intermediate;
  wire [31:0] op2_intermediate;
  wire op2_ready_intermediate;
  mux #(32, 2) op1_intermediate_mux(csr_access,
      {{27'b0, rs1}, imm}, op1_intermediate);
  mux #(32, 4) rename_op1_mux({uses_rs1, uses_pc},
      {32'b0, rat_rs1_tagval, addr, op1_intermediate}, rename_op1);
  mux #(1, 4) rename_op1ready_mux({uses_rs1, uses_pc},
      {1'b0, rat_rs1_valid, 1'b1, 1'b1}, rename_op1ready);
  mux #(32, 4) op2_intermediate_mux({uses_rs2, uses_imm},
      {rat_rs2_tagval, rat_rs2_tagval, imm, 32'b0}, op2_intermediate);
  mux #(32, 4) rename_op2_mux({uses_rs1, uses_pc},
      {32'b0, op2_intermediate, imm, 32'b0}, rename_op2);
  mux #(1, 4) op2_ready_intermediate_mux({uses_rs2, uses_imm},
      {rat_rs2_valid, rat_rs2_valid, 1'b1, 1'b0}, op2_ready_intermediate);
  mux #(1, 4) rename_op2ready_mux({uses_rs1, uses_pc},
      {1'b0, op2_ready_intermediate, 1'b1, 1'b1}, rename_op2ready);

  assign rename_imm = imm;

  // stall combinational
  assign rename_stall = (rename_exers_write & exers_stall) |
                 (rename_lsq_write & lsq_stall) |
                 (valid & csr_access & (~rob_rename_ishead | csr_stall));

  assign rename_rs1 = rs1;
  assign rename_rs2 = rs2;

  // delay tag allocation until dispatch
  assign rename_alloc = valid & ~rename_stall & ~rd[5];

  // if forwarding, send result to wb during tag allocation
  assign rename_wb_valid = valid & ~rename_stall & forward;
  assign rename_wb_result = result;

  // if both forwarding and dispatching, tell rob to ignore next wb cycle
  // (the forwarded data was already written to the rob target field in decode)
  assign rename_inhibit = valid & ~rename_stall & inhibit;


endmodule
