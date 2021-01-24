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
  output reg       rename_stall, // 

  // rat interface
  output reg [4:0] rename_rs1,
  output reg [4:0] rename_rs2,
  output reg       rename_alloc,
  input            rat_rs1_valid,
  input [31:0]     rat_rs1_tagval,
  input            rat_rs2_valid,
  input [31:0]     rat_rs2_tagval,

  // common rat/dispatch/wb signals
  output reg [5:0]  rename_rd,
  output reg [6:0]  rename_robid,

  // exers/lsq/csr interface
  output reg       rename_exers_write,
  output reg       rename_lsq_write,
  output reg       rename_csr_write,
  output reg [4:0] rename_op, //
  output reg       rename_op1ready,
  output reg [31:0] rename_op1,
  output reg       rename_op2ready,
  output reg [31:0] rename_op2,
  output reg [31:0] rename_imm, //
  input            exers_stall,
  input            lsq_stall,

  // wb interface
  output reg        rename_wb_valid,
  output reg [31:2] rename_wb_result,

  // rob interface
  input             rob_flush,
  output reg        rename_inhibit);

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

  
  always @(posedge clk) begin
    if (!rename_stall) begin
      valid <= decode_rename_valid;
      robid <= decode_robid;
      addr <= {decode_addr, 2'b00};
      op <= decode_rsop;
      rd <= decode_rd;
      uses_rs1 <= decode_uses_rs1;
      uses_rs2 <= decode_uses_rs2;
      uses_imm <= decode_uses_imm;
      uses_memory <= decode_uses_memory;
      uses_pc <= decode_uses_pc;
      csr_access <= decode_csr_access;
      forward <= decode_forward;
      inhibit <= decode_inhibit;
      result <= decode_target;
      rs1 <= decode_rs1;
      rs2 <= decode_rs2;
      imm <= decode_imm;
    end
    
    if (rst | rob_flush) begin
      // invalidate stage
      valid <= 0;
    end
  end


  always @(*) begin
    // reservation stations seq
    rename_lsq_write = valid & uses_memory;
    rename_csr_write = valid & csr_access;
    rename_exers_write = valid & (~uses_memory) & (~csr_access); 
    rename_op = op;
    rename_robid = robid;
    rename_rd = rd | {forward,5'b0}; // inhibit uses_rd if forwarding
      
    // OP generation
    case ({uses_rs1, uses_pc})
      // LUI
      2'b00: begin
        rename_op1ready = 1;
        rename_op1 = imm;
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
      // Normal instructions
      2'b10: begin
        rename_op1ready = rat_rs1_valid;
        rename_op1 = rat_rs1_tagval;
        casez ({uses_rs2, uses_imm})
          // OP/I and LD
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
    rename_stall = (rename_exers_write & exers_stall) | (rename_lsq_write & lsq_stall);

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
