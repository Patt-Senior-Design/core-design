// single-cycle alu
module scalu(
  input         clk,
  input         rst,

  // exers interface
  input         exers_scalu_issue,
  input [4:0]   exers_scalu_op,
  input [6:0]   exers_robid,
  input [5:0]   exers_rd,
  input [31:0]  exers_op1,
  input [31:0]  exers_op2,
  output        scalu_stall,

  // wb interface
  output        scalu_valid,
  output        scalu_error,
  output [4:0]  scalu_ecause,
  output [6:0]  scalu_robid,
  output [5:0]  scalu_rd,
  output reg[31:0] scalu_result,
  input         wb_scalu_stall,

  // rob interface
  input         rob_flush);

  function automatic [4:0] compute_priority_vector (input[31:0] vector);
    integer j;
    begin
      for (j = 0; j < RS_ENTRIES; j=j+1)
        if (vector[j] == 1) begin
          compute_priority_vector = (1 << j);
          j = RS_ENTRIES;
        end
    end
  endfunction
  
  reg valid;
  reg[4:0] op;
  reg[6:0] robid;
  reg[5:0] rd;
  reg[31:0] op1;
  reg[31:0] op2;

  reg[31:0] p_vector;
  reg[4:0] p_index;

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      valid <= 1'b0;
    end
    else if (~scalu_stall) begin
      valid <= exers_scalu_issue;
      if (exers_scalu_issue) begin
        op <= exers_scalu_op;
        robid <= exers_robid;
        rd <= exers_rd;
        op1 <= exers_op1;
        op2 <= exers_op2;
      end
    end
  end


  assign scalu_stall = valid & wb_scalu_stall;
  assign scalu_valid = valid;
  assign scalu_robid = robid;
  assign scalu_rd = rd;
  assign scalu_error = 0;
  assign scalu_ecause = 0;

  always @(*) begin
    if (op[4]) begin
      casez(op[2:0])
        3'b000: scalu_result = (op[3] ? op1 + (~op2+1) : op1 + op2); // ADD,SUB
        3'b001: scalu_result = (op1 << op2[4:0]); // SLL
        3'b010: scalu_result = ($signed(op1) < $signed(op2)); // SLT
        3'b011: scalu_result = (op1 < op2); // SLTU
        3'b100: scalu_result = (op[3] ? (op1 == op2) : (op1 ^ op2)); // XOR, SEQ
        3'b101: scalu_result = (op[3] ? $signed($signed(op1) >>> op2[4:0]) : (op1 >> op2[4:0])); // SRL, SRA
        3'b110: scalu_result = (op1 | op2);
        3'b111: scalu_result = (op1 & op2);
        default: scalu_result = 32'bx;
      endcase
    end
    // ALU Extensions
    else begin
      p_vector = compute_priority_vector(op1 & ~op2);
      p_index = $clog2(p_vector);
      casez(op[2:0])
        // Priority Find: Encoder
        3'b000: scalu_result = {{27{~|p_vector}} , p_index};
        // Priority Clear
        3'b001: scalu_result = op1 ^ p_vector;
        default: scalu_result = 32'bx;
      endcase
    end
  end


endmodule
