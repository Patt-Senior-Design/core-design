// RISC-V instruction decoder
module decode(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_de_valid,
  input         fetch_de_error,
  input [31:1]  fetch_de_addr,
  input [31:0]  fetch_de_insn,
  input [15:0]  fetch_de_bptag,
  input         fetch_de_bptaken,
  output        decode_stall,

  // rob interface
  output        decode_rob_valid,
  output        decode_error,
  output [1:0]  decode_ecause,
  output [6:0]  decode_retop,
  output [15:0] decode_bptag,
  output        decode_bptaken,
  input         rob_flush,
  input         rob_full,
  input [6:0]   rob_robid,

  // common rob/rename signals
  output [5:0]  decode_rd,
  output [31:2] decode_addr,
  output        decode_forward,
  output [31:2] decode_target,

  // rename interface
  output        decode_rename_valid,
  output [4:0]  decode_rsop,
  output [6:0]  decode_robid,
  output        decode_uses_rs1,
  output        decode_uses_rs2,
  output        decode_uses_imm,
  output        decode_uses_memory,
  output        decode_uses_pc,
  output        decode_csr_access,
  output        decode_inhibit,
  output [4:0]  decode_rs1,
  output [4:0]  decode_rs2,
  output [31:0] decode_imm,
  input         rename_stall);

  wire        valid;
  wire        error;
  wire [31:1] addr;
  wire [31:0] insn;
  wire [15:0] bptag;
  wire        bptaken;

  wire        fmt_r, fmt_i, fmt_s, fmt_b, fmt_u, fmt_j, fmt_inv;
  wire [31:0] imm;
  wire [4:0]  rsop;

  localparam
    ERR_IALIGN   = 2'b00,
    ERR_IFAULT   = 2'b01,
    ERR_IILLEGAL = 2'b10;


  localparam
    OPC_LOAD      = 5'b00000,
    OPC_LOADFP    = 5'b00001,
    OPC_CUSTOM0   = 5'b00010,
    OPC_MISCMEM   = 5'b00011,
    OPC_OPIMM     = 5'b00100,
    OPC_AUIPC     = 5'b00101,
    OPC_OPIMM32   = 5'b00110,
    OPC_48B0      = 5'b00111,
    OPC_STORE     = 5'b01000,
    OPC_STOREFP   = 5'b01001,
    OPC_CUSTOM1   = 5'b01010,
    OPC_AMO       = 5'b01011,
    OPC_OP        = 5'b01100,
    OPC_LUI       = 5'b01101,
    OPC_OP32      = 5'b01110,
    OPC_64B       = 5'b01111,
    OPC_MADD      = 5'b10000,
    OPC_MSUB      = 5'b10001,
    OPC_NMSUB     = 5'b10010,
    OPC_NMADD     = 5'b10011,
    OPC_OPFP      = 5'b10100,
    OPC_RESERVED0 = 5'b10101,
    OPC_CUSTOM2   = 5'b10110,
    OPC_48B1      = 5'b10111,
    OPC_BRANCH    = 5'b11000,
    OPC_JALR      = 5'b11001,
    OPC_RESERVED1 = 5'b11010,
    OPC_JAL       = 5'b11011,
    OPC_SYSTEM    = 5'b11100,
    OPC_RESERVED2 = 5'b11101,
    OPC_CUSTOM3   = 5'b11110,
    OPC_80B       = 5'b11111;

  // derived signals
  wire [2:0] funct3;
  assign funct3 = insn[14:12];

  wire insn_load, insn_jalr, insn_auipc, insn_csr, insn_lbcmp, insn_aluext;
  assign insn_load = (insn[6:2] == OPC_LOAD);
  assign insn_jalr = (insn[6:2] == OPC_JALR);
  assign insn_auipc = (insn[6:2] == OPC_AUIPC);
  assign insn_csr = (insn[6:2] == OPC_SYSTEM) & (funct3[1:0] != 0);
  assign insn_lbcmp = (insn[6:2] == OPC_CUSTOM0) & (funct3[1:0] == 2'b11);
  assign insn_aluext = (insn[6:2] == OPC_CUSTOM1);

  wire insn_complex;
  assign insn_complex = fmt_r & insn[25];

  wire [2:0] brop;
  assign brop = {~|funct3[2:1],funct3[2:1]};

  // SRLI alternation: special case
  wire altop;
  assign altop = (fmt_r | (funct3 == 3'b101)) & insn[30];

  wire [4:0] rs1, rs2, rd;
  assign rs1 = insn[19:15];
  assign rs2 = insn[24:20];
  assign rd = insn[11:7];

  wire [2:0] csrop;
  mux #(3, 2) csrop_mux(funct3[1] & (rs1 == 0), {3'b000, funct3}, csrop);

  wire uses_rd, uses_rs1, uses_rs2;
  assign uses_rd = (fmt_r | fmt_i | fmt_u | fmt_j) & (rd != 0);
  assign uses_rs1 = fmt_r | (fmt_i & (~insn_csr | ~funct3[2])) | fmt_s | fmt_b;
  assign uses_rs2 = fmt_r | fmt_s | fmt_b;

  wire target_ntaken;
  assign target_ntaken = (fmt_b & bptaken) | insn_jalr;

  // TODO misaligned target?
  wire [31:1] target;
  wire [31:1] target_rhs;
  mux #(31, 2) target_mux(target_ntaken, {31'd2, imm[31:1]}, target_rhs);
  rca #(31) target_adder(0, {addr[31:2], 1'b0}, target_rhs, target);

  // fetch interface
  assign decode_stall = rob_full | rename_stall;

  // rob interface
  assign decode_rob_valid = valid & ~rename_stall;
  assign decode_error = error | fmt_inv;
  mux #(2, 4) decode_ecause_mux({error, addr[1]}, {ERR_IALIGN, ERR_IFAULT, ERR_IILLEGAL, ERR_IILLEGAL}, decode_ecause);
  assign decode_retop = {fmt_b,insn_csr,insn_jalr,fmt_s,funct3};
  assign decode_bptag = bptag;
  assign decode_bptaken = bptaken;

  // common rob/rename signals
  assign decode_rd = {~uses_rd,rd};
  assign decode_addr = addr[31:2];
  assign decode_forward = insn_jalr;
  assign decode_target = target[31:2];

  // rename interface
  assign decode_rename_valid = valid & ~decode_error & ~rob_full;
  assign decode_rsop = rsop;
  assign decode_robid = rob_robid;
  assign decode_uses_rs1 = uses_rs1;
  assign decode_uses_rs2 = uses_rs2;
  assign decode_uses_imm = ~fmt_r & ~fmt_b;
  assign decode_uses_memory = insn_load | fmt_s | insn_lbcmp;
  assign decode_uses_pc = fmt_j | insn_auipc;
  assign decode_csr_access = insn_csr;
  assign decode_inhibit = insn_jalr;
  assign decode_rs1 = rs1;
  assign decode_rs2 = rs2;
  mux #(32, 2) decode_imm_mux(fmt_j, {32'd4, imm}, decode_imm);

  flop valid_flop       (clk, rst | rob_flush, 0, ~decode_stall, fetch_de_valid, valid);
  flop error_flop       (clk, 0, 0, ~decode_stall, fetch_de_error, error);
  flop #(31) addr_flop  (clk, 0, 0, ~decode_stall, fetch_de_addr, addr);
  flop #(32) insn_flop  (clk, 0, 0, ~decode_stall, fetch_de_insn, insn);
  flop #(16) bptag_flop (clk, 0, 0, ~decode_stall, fetch_de_bptag, bptag);
  flop bptaken_flop     (clk, 0, 0, ~decode_stall, fetch_de_bptaken, bptaken);

  // format decoder
  assign fmt_r = (insn[6:2] == OPC_OP) | (insn[6:2] == OPC_CUSTOM0) | (insn[6:2] == OPC_CUSTOM1);
  assign fmt_i = (insn[6:2] == OPC_OPIMM) | (insn[6:2] == OPC_LOAD) | (insn[6:2] == OPC_JALR) |
      (insn[6:2] == OPC_MISCMEM) | (insn[6:2] == OPC_SYSTEM);
  assign fmt_s = insn[6:2] == OPC_STORE;
  assign fmt_b = insn[6:2] == OPC_BRANCH;
  assign fmt_u = (insn[6:2] == OPC_LUI) | (insn[6:2] == OPC_AUIPC);
  assign fmt_j = insn[6:2] == OPC_JAL;
  assign fmt_inv = ~|{fmt_r, fmt_i, fmt_s, fmt_b, fmt_u, fmt_j};

  wire [31:0] fmt_i_imm, fmt_s_imm, fmt_b_imm, fmt_u_imm, fmt_j_imm;
  sext #(32, 12) fmt_i_sext(insn[31:20], fmt_i_imm);
  sext #(32, 12) fmt_s_sext({insn[31:25], insn[11:7]}, fmt_s_imm);
  sext #(32, 13) fmt_b_sext({insn[31], insn[7], insn[30:25], insn[11:8], 1'b0}, fmt_b_imm);
  assign fmt_u_imm = {insn[31:12], 12'b0};
  sext #(32, 21) fmt_j_sext({insn[31], insn[19:12], insn[20], insn[30:21], 1'b0}, fmt_j_imm);

  // immediate generator
  assign imm = {32{fmt_i}} & fmt_i_imm | {32{fmt_s}} & fmt_s_imm |
      {32{fmt_b}} & fmt_b_imm | {32{fmt_u}} & fmt_u_imm | {32{fmt_j}} & fmt_j_imm;

  assign rsop = {5{decode_uses_memory}} & {1'b0,fmt_s,funct3} | {5{fmt_j | insn_jalr | fmt_u}} &
      5'b00000 | {5{fmt_b}} & {2'b01, brop} | {5{insn_csr}} & {2'b00, csrop} |
      {5{!(decode_uses_memory | fmt_j | fmt_u | fmt_b | insn_jalr | insn_csr)}} &
      {insn_complex | insn_aluext, insn_complex | altop, funct3};

`ifndef SYNTHESIS
  always @(posedge clk)
    if(valid & ~decode_stall)
      top.tb_trace_decode(
        decode_robid,
        insn,
        imm);
`endif

endmodule
