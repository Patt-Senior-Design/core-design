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

  // common rob/rename signals
  output [31:2] decode_addr,
  output [5:0]  decode_rd,

  // rob interface
  output        decode_rob_valid,
  output        decode_error,
  output [1:0]  decode_ecause,
  output [6:0]  decode_retop,
  output [15:0] decode_bptag,
  output        decode_bptaken,
  output [31:2] decode_target,
  input         rob_flush,
  input         rob_full,
  input [7:0]   rob_robid,

  // rename interface
  output        decode_rename_valid,
  output [4:0]  decode_rsop,
  output [7:0]  decode_robid,
  output        decode_uses_rs1,
  output        decode_uses_rs2,
  output        decode_uses_imm,
  output        decode_uses_memory,
  output        decode_uses_pc,
  output        decode_csr_access,
  output [4:0]  decode_rs1,
  output [4:0]  decode_rs2,
  output [31:0] decode_imm,
  input         rename_stall);

  reg        valid;
  reg        error;
  reg [31:1] addr;
  reg [31:0] insn;
  reg [15:0] bptag;
  reg        bptaken;

  reg        fmt_r, fmt_i, fmt_s, fmt_b, fmt_u, fmt_j, fmt_inv;
  reg [31:0] imm;
  reg [4:0]  rsop;

  localparam
    ERR_IALIGN   = 0,
    ERR_IFAULT   = 1,
    ERR_IILLEGAL = 2;

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

  wire insn_load, insn_jalr, insn_auipc, insn_csr;
  assign insn_load = (insn[6:2] == OPC_LOAD);
  assign insn_jalr = (insn[6:2] == OPC_JALR);
  assign insn_auipc = (insn[6:2] == OPC_AUIPC);
  assign insn_csr = (insn[6:2] == OPC_SYSTEM) & (funct3[1:0] != 0);

  wire insn_complex;
  assign insn_complex = fmt_r & insn[25];

  wire [2:0] brop;
  assign brop = {~|funct3[2:1],funct3[2:1]};

  wire [4:0] rs1, rs2, rd;
  assign rs1 = insn[19:15];
  assign rs2 = insn[24:20];
  assign rd = insn[11:7];

  wire uses_rd, uses_rs1, uses_rs2;
  assign uses_rd = (fmt_r | fmt_i | fmt_u | fmt_j) & (rd != 0);
  assign uses_rs1 = fmt_r | (fmt_i & (~insn_csr | ~funct3[2])) | fmt_s | fmt_b;
  assign uses_rs2 = fmt_r | fmt_s | fmt_b;

  // TODO misaligned target?
  wire [31:1] target;
  assign target = {addr[31:2],1'b0} + imm[31:1];

  // fetch interface
  assign decode_stall = rob_full | rename_stall;

  // common rob/rename signals
  assign decode_addr = addr[31:2];
  assign decode_rd = {~uses_rd,insn[11:7]};

  // rob interface
  assign decode_rob_valid = valid & ~rename_stall;
  assign decode_error = error | fmt_inv;
  assign decode_ecause = error ? (addr[1] ? ERR_IALIGN : ERR_IFAULT) : ERR_IILLEGAL;
  assign decode_retop = {fmt_b,funct3[0],insn_jalr,fmt_s,funct3};
  assign decode_bptag = bptag;
  assign decode_bptaken = bptaken;
  assign decode_target = target[31:2];

  // rename interface
  assign decode_rename_valid = valid & ~decode_error & ~rob_full;
  assign decode_rsop = rsop;
  assign decode_robid = rob_robid;
  assign decode_uses_rs1 = uses_rs1;
  assign decode_uses_rs2 = uses_rs2;
  assign decode_uses_imm = ~fmt_r & ~fmt_b;
  assign decode_uses_memory = insn_load | fmt_s;
  assign decode_uses_pc = fmt_j | insn_jalr | insn_auipc;
  assign decode_csr_access = insn_csr;
  assign decode_rs1 = rs1;
  assign decode_rs2 = rs2;
  assign decode_imm = imm;

  always @(posedge clk)
    if(rst | rob_flush)
      valid <= 0;
    else if(~decode_stall) begin
      valid <= fetch_de_valid;
      if(fetch_de_valid) begin
        error <= fetch_de_error;
        addr <= fetch_de_addr;
        insn <= fetch_de_insn;
        bptag <= fetch_de_bptag;
        bptaken <= fetch_de_bptaken;
      end
    end

  // format decoder
  always @(*) begin
    {fmt_r,fmt_i,fmt_s,fmt_b,fmt_u,fmt_j,fmt_inv} = 0;

    if(insn[1:0] != 2'b11)
      fmt_inv = 1;
    else case(insn[6:2])
      // implemented opcodes
      OPC_OP: fmt_r = 1;
      OPC_OPIMM: fmt_i = 1;

      OPC_LUI: fmt_u = 1;
      OPC_AUIPC: fmt_u = 1;

      OPC_LOAD: fmt_i = 1;
      OPC_STORE: fmt_s = 1;

      OPC_BRANCH: fmt_b = 1;
      OPC_JAL: fmt_j = 1;
      OPC_JALR: fmt_i = 1;

      OPC_MISCMEM: fmt_i = 1;
      OPC_SYSTEM: fmt_i = 1;

      // unimplemented opcodes
      // floating point
      OPC_OPFP: fmt_inv = 1;
      OPC_LOADFP: fmt_inv = 1;
      OPC_STOREFP: fmt_inv = 1;
      OPC_MADD: fmt_inv = 1;
      OPC_MSUB: fmt_inv = 1;
      OPC_NMSUB: fmt_inv = 1;
      OPC_NMADD: fmt_inv = 1;

      // atomic memory operations
      OPC_AMO: fmt_inv = 1;

      // RV64 32-bit insns (unused in RV32)
      OPC_OP32: fmt_inv = 1;
      OPC_OPIMM32: fmt_inv = 1;

      // custom instructions
      OPC_CUSTOM0: fmt_inv = 1;
      OPC_CUSTOM1: fmt_inv = 1;
      OPC_CUSTOM2: fmt_inv = 1;
      OPC_CUSTOM3: fmt_inv = 1;

      // reserved
      OPC_RESERVED0: fmt_inv = 1;
      OPC_RESERVED1: fmt_inv = 1;
      OPC_RESERVED2: fmt_inv = 1;
      OPC_48B0: fmt_inv = 1;
      OPC_48B1: fmt_inv = 1;
      OPC_64B: fmt_inv = 1;
      OPC_80B: fmt_inv = 1;
    endcase
  end

  // immediate generator
  always @(*) begin
    imm = 0;
    case(1)
      fmt_i: imm = $signed(insn[31:20]);
      fmt_s: imm = $signed({insn[31:25],insn[11:7]});
      fmt_b: imm = $signed({insn[31],insn[7],insn[30:25],insn[11:8],1'b0});
      fmt_u: imm = {insn[31:12],12'b0};
      fmt_j: imm = $signed({insn[31],insn[19:12],insn[20],insn[30:21],1'b0});
    endcase
  end

  // rsop
  always @(*)
    case(1)
      decode_uses_memory:
        rsop = {1'b0,fmt_s,funct3};
      insn_complex:
        rsop = {2'b11,funct3};
      insn_jalr:
        rsop = 5'b10000;
      fmt_b:
        rsop = {2'b01,brop};
      default:
        rsop = {1'b0,fmt_r & insn[30],funct3};
    endcase

  always @(posedge clk)
    if(valid & ~decode_stall)
      top.trace_decode(
        decode_robid[6:0],
        insn);

endmodule
