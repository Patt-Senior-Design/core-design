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
  wire[31:0] sc_result;

  reg[31:0] p_vector;
  reg[4:0] p_index;
  
  wire is_mc_op;
  assign is_mc_op = &op[4:3];

  // MC Outputs
  assign done = is_mc_op ? done_mc : done_sc;
  assign mcalu_stall = (valid & (~done)) | (valid & done & wb_mcalu_stall);
  assign mcalu_valid = done;
  assign mcalu_robid = robid;
  assign mcalu_rd = rd;
  assign mcalu_error = 0;
  assign mcalu_ecause = 0;

  // MCALU Latches
  always @(posedge clk) begin
    if (rst | rob_flush) begin
      valid <= 1'b0;
      op[4:3] <= 1'b0; // CAN BE REMOVED IN 2-STATE
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
  alu_simple sc_alu(
    .op(op),
    .op1(op1),
    .op2(op2),
    .sc_result(sc_result));

  always @(*) begin
    if (!is_mc_op) begin
      mcalu_result = sc_result;
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
  reg [35:0] ptl_prod; // Extra MSB, 2 extra bits for negation correction
  reg [33:0] ptl_prod_i;
  reg [63:0] mul_result;
  reg se_bit;

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
  reg [63:0] d_acc, d_acc_c;
  reg [33:0] dsor, dsor_c;
  reg [4:0] d_iter, d_iter_c;
  reg dvd_sgn, dvd_sgn_c;
  reg dsor_sgn, dsor_sgn_c;
  
  // Restoring combinational
  reg [31:0] dvd;
  reg [64:0] d_shf;
  reg [31:0] ptl_rem_n;
  reg [33:0] cmp_res;
  reg [31:0] div_result;

  wire [33:0] ptl_rem;
  assign ptl_rem = {1'b0, d_shf[64:32]};

  // State control
  reg [1:0] d_state;
  reg [1:0] d_next_state;
  /* */

  always @(*) begin
    if (is_mc_op) begin
      if (op[2]) begin  // DIV,REM
        casez(d_state) 
          INIT: begin
            // Positive dividend, negative divisor
            dvd_sgn_c = op1[31] & ~op[0];
            dsor_sgn_c = op2[31] & ~op[0]; 
            dvd = (dvd_sgn_c ? ~op1 + 1 : op1);
            dsor_c[33:0] = (dsor_sgn_c ? {2'b11, op2} : {2'b11, ~op2} + 1);
            // Output init
            done_mc = 0;
            d_iter_c = 5'b00000;
            d_acc_c = {32'b0, dvd}; 
            d_next_state = PROG;
          end
          PROG: begin
            d_shf = (d_acc << 1);
            cmp_res = { 1'b0, d_shf[64:32] } + dsor;
            // Quotient shift-in and new remainder gen
            d_shf[0] = ~cmp_res[33]; 
            ptl_rem_n = (cmp_res[33] ? ptl_rem[31:0] : cmp_res);
            // Output
            done_mc = 0;
            d_acc_c = {ptl_rem_n, d_shf[31:0]};
            d_iter_c = d_iter - 1;
            d_next_state = (d_iter_c ? PROG : PROG_FINAL); 
          end
          PROG_FINAL: begin
            // Output
            done_mc = 1;
            div_result = (op[1] ? d_acc[63:32] : d_acc[31:0]);
            // WRITEBACK: Flip sign based on inputs.
            // Rem is same sign as dsor sign, quotient is XOR of dsor and dvd sign
            mcalu_result = (dvd_sgn ^ (~op[1] & dsor_sgn) ? ~div_result + 1 : div_result);
            d_next_state = (mcalu_stall ? PROG_FINAL : INIT);
          end
        endcase
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
            se_bit = op1[31] & (op[1] ^ op[0]);
            casez({double, single})
              2'b?1: ptl_prod_i = {34{neg}} ^ { {2{se_bit}}, op1 }; // Sign-extend Op
              2'b1?: ptl_prod_i = {34{neg}} ^ { se_bit, op1, 1'b0 }; 
              default: ptl_prod_i = {34{neg}} ^ 33'b0;
            endcase
            ptl_prod = {ptl_prod_i, 1'b0, inv};
            acc_se = ($signed(acc) >>> 2); // Sign-extend Acc
            // Output
            done_mc = 0;
            x0_c = acc[1];
            iter_c = iter - 1;
            acc_c = (acc_se + {ptl_prod, 30'b0});
            inv_c = neg;
            next_state = (iter_c ? PROG : PROG_FINAL);
          end
          PROG_FINAL: begin
            ptl_prod_i = (x0 & ~(~op[1]&op[0]) ? {2'b0, op1} : 34'b0);
            ptl_prod = {ptl_prod_i, 1'b0, inv};
            acc_se = ($signed(acc) >>> 2);
            // Output
            done_mc = 1;
            mul_result = (acc_se + {ptl_prod, 30'b0});
            // WRITEBACK
            mcalu_result = (|op[1:0] ? mul_result[63:32] : mul_result[31:0]);
            next_state = (mcalu_stall ? PROG_FINAL : INIT);
          end
        endcase
      end
    end
  end

  // Complex State machine controller
  always @(posedge clk) begin
    if (rst | rob_flush) begin
      state <= INIT;
      d_state <= INIT;
    end
    else if (valid & is_mc_op) begin
      // MUL Control
      state <= next_state;
      x0 <= x0_c;
      acc <= acc_c;
      iter <= iter_c;
      inv <= inv_c;
      // DIV Control
      d_state <= d_next_state;
      d_acc <= d_acc_c;
      d_iter <= d_iter_c;
      dsor <= dsor_c;
      dvd_sgn <= dvd_sgn_c;
      dsor_sgn <= dsor_sgn_c;
    end
  end



endmodule
