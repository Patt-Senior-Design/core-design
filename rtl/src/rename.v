// register rename and instruction dispatch unit
module rename (
    input clk,
    input rst,

    // decode interface
    input             decode_rename_valid,
    input      [31:2] decode_addr,
    input      [ 4:0] decode_rsop,
    input      [ 6:0] decode_robid,
    input      [ 5:0] decode_rd,
    input             decode_uses_rs1,
    input             decode_uses_rs2,
    input             decode_uses_imm,
    input             decode_uses_memory,
    input             decode_uses_pc,
    input             decode_csr_access,
    input             decode_forward,
    input             decode_inhibit,
    input      [31:2] decode_target,
    input      [ 4:0] decode_rs1,
    input      [ 4:0] decode_rs2,
    input      [31:0] decode_imm,
    output reg        rename_stall,

    // rat interface
    output reg [ 4:0] rename_rs1,
    output reg [ 4:0] rename_rs2,
    output reg        rename_alloc,
    input             rat_rs1_valid,
    input      [31:0] rat_rs1_tagval,
    input             rat_rs2_valid,
    input      [31:0] rat_rs2_tagval,

    // common rat/dispatch/wb signals
    output reg [5:0] rename_rd,
    output reg [6:0] rename_robid,

    // exers/lsq/csr interface
    output reg        rename_exers_write,
    output reg        rename_lsq_write,
    output reg        rename_csr_write,
    output reg [ 4:0] rename_op,
    output reg        rename_op1ready,
    output reg [31:0] rename_op1,
    output reg        rename_op2ready,
    output reg [31:0] rename_op2,
    output reg [31:0] rename_imm,
    input             exers_stall,
    input             lsq_stall,
    input             csr_stall,

    // wb interface
    output reg        rename_wb_valid,
    output reg [31:2] rename_wb_result,

    // rob interface
    input      rob_flush,
    input      rob_rename_ishead,
    output reg rename_inhibit
);

  // decode signals
  reg valid;
  reg stall;
  reg [6:0] robid;
  reg [31:0] addr;
  reg [4:0] op;
  reg [5:0] rd;
  reg uses_rs1;
  reg uses_rs2;
  reg uses_imm;
  reg uses_memory;
  reg uses_pc;
  reg csr_access;
  reg forward;
  reg inhibit;
  reg [31:2] result;
  reg [4:0] rs1;
  reg [4:0] rs2;
  reg [31:0] imm;

  `FLOP_ER(valid, 1, rename_stall, decode_rename_valid, rst | rob_flush);
  `FLOP_E(robid, 7, rename_stall, robid);
  `FLOP_E(addr, 32, rename_stall, {decode_addr, 2'b00});
  `FLOP_E(op, 5, rename_stall, decode_rsop);
  `FLOP_E(rd, 6, rename_stall, decode_rd);
  `FLOP_E(uses_rs1, 1, rename_stall, decode_uses_rs1);
  `FLOP_E(uses_rs2, 1, rename_stall, decode_uses_rs2);
  `FLOP_E(uses_imm, 1, rename_stall, decode_uses_imm);
  `FLOP_E(uses_memory, 1, rename_stall, decode_uses_memory);
  `FLOP_E(uses_pc, 1, rename_stall, decode_uses_pc);
  `FLOP_E(csr_access, 1, rename_stall, decode_csr_access);
  `FLOP_E(forward, 1, rename_stall, forward);
  `FLOP_E(inhibit, 1, rename_stall, inhibit);
  `FLOP_E(result, 30, rename_stall, decode_target);
  `FLOP_E(rs1, 5, rename_stall, decode_rs1);
  `FLOP_E(rs2, 5, rename_stall, decode_rs2);
  `FLOP_E(imm, 32, rename_stall, decode_imm);

  always @(*) begin
    // reservation stations seq
    rename_lsq_write = valid & uses_memory;
    rename_exers_write = valid & (~uses_memory) & (~csr_access);
    rename_csr_write = valid & csr_access & rob_rename_ishead & ~rob_flush;
    rename_op = op;
    rename_robid = robid;
    rename_rd = rd | {forward, 5'b0};  // inhibit uses_rd if forwarding

    // OP generation
    casez ({
      uses_rs1, uses_pc
    })
      // LUI, CSR Imm
      2'b00: begin
        rename_op1ready = 1;
        rename_op1 = (csr_access ? {27'b0, rs1} : imm);
        rename_op2ready = 1;
        rename_op2 = 0;
      end
      // AUIPC
      2'b01: begin
        rename_op1ready = 1;
        rename_op1 = addr;
        rename_op2ready = 1;
        rename_op2 = imm;
      end
      // Most instructions
      2'b10: begin
        rename_op1ready = rat_rs1_valid;
        rename_op1 = rat_rs1_tagval;
        casez ({
          uses_rs2, uses_imm
        })
          // OP/I, LD, CSR
          2'b01: begin
            rename_op2ready = 1;
            rename_op2 = imm;
          end
          // OP, ST
          2'b1?: begin
            rename_op2ready = rat_rs2_valid;
            rename_op2 = rat_rs2_tagval;
          end
          // N/A
          default: begin
            rename_op2ready = 1'bx;
            rename_op2 = 32'bx;
          end
        endcase
      end
      // N/A
      default: begin
        rename_op1ready = 1'bx;
        rename_op1 = 32'bx;
      end
    endcase

    rename_imm = imm;

    // stall combinational
    rename_stall = (rename_exers_write & exers_stall) | (rename_lsq_write & lsq_stall) | (
        valid & csr_access & (~rob_rename_ishead | csr_stall));

    rename_rs1 = rs1;
    rename_rs2 = rs2;

    // delay tag allocation until dispatch
    rename_alloc = valid & ~rename_stall & ~rd[5];

    // if forwarding, send result to wb during tag allocation
    rename_wb_valid = valid & ~rename_stall & forward;
    rename_wb_result = result;

    // if both forwarding and dispatching, tell rob to ignore next wb cycle
    // (the forwarded data was already written to the rob target field in decode)
    rename_inhibit = valid & ~rename_stall & inhibit;
  end


endmodule
