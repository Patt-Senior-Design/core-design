// multi-cycle alu
module mcalu(
  input         clk,
  input         rst,

  // exers interface
  input         exers_mcalu_issue,
  input [4:0]   exers_mcalu_op,
  input [6:0]   exers_robid,
  input [5:0]   exers_rd,
  input [31:0]  exers_op1,
  input [31:0]  exers_op2,
  output        mcalu_stall,

  // wb interface
  output        mcalu_valid,
  output        mcalu_error,
  output [4:0]  mcalu_ecause,
  output [6:0]  mcalu_robid,
  output [5:0]  mcalu_rd,
  output reg [31:0] mcalu_result,
  input         wb_mcalu_stall,

  // rob interface
  input         rob_flush);

  localparam
    INIT = 2'b00,
    PROG = 2'b01,
    PROG_FINAL = 2'b10;

  reg valid;
  reg done_sc, done_mc;
  wire done;
  reg[4:0] op;
  reg[7:0] robid;
  reg[5:0] rd;
  reg[31:0] op1;
  reg[31:0] op2;
  
  assign done = op[4] ? done_mc : done_sc;
  assign mcalu_stall = (valid & (~done)) | (valid & done & wb_mcalu_stall);
  assign mcalu_valid = done;
  assign mcalu_robid = robid;
  assign mcalu_rd = rd;
  // Error TBD
  assign mcalu_error = 0;
  assign mcalu_ecause = 0;

  // MCALU Latches
  always @(posedge clk) begin
    if (rst | rob_flush) begin
      valid <= 1'b0;
      op[4] <= 1'b0; // CAN BE REMOVED IN 2-STATE
    end
    else if (~mcalu_stall) begin
      valid <= exers_mcalu_issue;
      if (exers_mcalu_issue) begin
        op <= exers_mcalu_op;
        robid <= exers_robid;
        rd <= exers_rd;
        op1 <= exers_op1;
        op2 <= exers_op2;
      end
    end
  end

  // Simple Ops  
  // JAL/R TBD
  always @(*) begin
    if (!op[4]) begin
      casez(op[2:0])
        3'b000: mcalu_result = (op[3] ? op1 + (~op2+1) : op1 + op2); // ADD,SUB
        3'b001: mcalu_result = (op1 << op2[4:0]); // SLL
        3'b010: mcalu_result = ($signed(op1) < $signed(op2)); // SLT
        3'b011: mcalu_result = (op1 < op2); // SLTU
        3'b100: mcalu_result = (op[3] ? (op1 == op2) : (op1 ^ op2)); // XOR, SEQ
        3'b101: mcalu_result = (op[3] ? $signed($signed(op1) >>> op2[4:0]) : (op1 >> op2[4:0])); // SRL, SRA
        3'b110: mcalu_result = (op1 | op2);
        3'b111: mcalu_result = (op1 & op2);
        default: mcalu_result = 32'bx;
      endcase
      done_sc = valid;
    end
  end
 
  // Complex Ops
  /* MUL */
  // Local storage
  reg [65:0] acc, acc_c, acc_se; // Extra bit for last operation
  reg[3:0] iter, iter_c;
  reg x0, x0_c;
  reg inv, inv_c;

  // Booth combinational
  reg [35:0] mplier; // Extra MSB, 2 extra bits for negation correction
  reg [33:0] mpli_op;
  reg [63:0] mul_result;
  
  wire single, double, neg;
  wire x2, x1;
  assign {x2, x1} = acc[1:0];
  assign single = x1 ^ x0;
  assign double = ((~x2 & x1 & x0) | (x2 & (~x1) & (~x0)));
  assign neg = x2;

  // State control
  reg [1:0] state;
  reg [1:0] next_state;
  /* */

  /* DIV */
  reg [31:0] dsor;
  reg [31:0] dnd;
  /* */

  always @(*) begin
    if (op[4]) begin
      if (op[2]) begin  // DIV,REM
        /*casez(state) 
          INIT: begin
            done_mc = 0;
            dnd = op1;
          end
        endcase*/
      end
      else begin  // MUL
        casez(state)
          INIT: begin  
            // Output
            done_mc = 0;
            x0_c = 0;
            iter_c = 4'b0000;
            acc_c = {33'b0, op2};
            inv_c = 0;
            next_state = PROG;
          end
          PROG: begin 
            casez({double, single})
              2'b?1: mpli_op = {34{neg}} ^ { {2{op1[31]&(op[1]^op[0])}}, op1}; // Sign-extend Op
              2'b1?: mpli_op = {34{neg}} ^ {op1[31]&(op[1]^op[0]), op1, 1'b0}; 
              default: mpli_op = {34{neg}} ^ 33'b0;
            endcase
            mplier = {mpli_op, 1'b0, inv};
            acc_se = ($signed(acc) >>> 2); // Sign-extend Acc
            // Output
            done_mc = 0;
            x0_c = acc[1];
            iter_c = iter - 1;
            acc_c = (acc_se + {mplier, 30'b0});
            inv_c = neg;
            next_state = (iter_c ? PROG : PROG_FINAL);
          end
          PROG_FINAL: begin
            mpli_op = (x0 & ~(~op[1]&op[0]) ? {2'b0, op1} : 34'b0);
            mplier = {mpli_op, 1'b0, inv};
            acc_se = ($signed(acc) >>> 2);
            // Output
            done_mc = 1;
            mul_result = (acc_se + {mplier, 30'b0});
            mcalu_result = (|op[1:0] ? mul_result[63:32] : mul_result[31:0]);
            next_state = (mcalu_stall ? PROG_FINAL : INIT);
          end
        endcase
      end
    end
  end

  // Complex State machine controller
  always @(posedge clk) begin
    if (rst | rob_flush)
      state <= INIT;
    else if (valid) begin
      // MUL Control
      state <= next_state;
      x0 <= x0_c;
      acc <= acc_c;
      iter <= iter_c;
      inv <= inv_c;
      // DIV Control

    end
  end



endmodule
