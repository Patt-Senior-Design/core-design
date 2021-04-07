// Single Cycle ALU operations
module alu_simple(
  // exec unit interface
  input [4:0]       op,
  input [31:0]      op1,
  input [31:0]      op2,
  output reg [31:0] sc_result);

  function automatic [31:0] compute_priority_vector (input[31:0] vector);
    integer j;
    integer result;
    begin
      for (j = 0; j < 32; j=j+1)
        if (vector[j] == 1) begin
          result = (1 << j);
          j = 32;
        end
      compute_priority_vector = (|vector ?  result : 0);
    end
  endfunction

  wire [31:0] p_vector;
  wire [4:0] p_index;
  assign p_vector = compute_priority_vector(op1 & ~op2);
  /*verilator lint_off WIDTH*/
  assign p_index = $clog2(p_vector);
  /*verilator lint_on WIDTH*/

  always @(*) begin
    sc_result = 0;
    if (~op[4]) begin
      casez(op[2:0])
        3'b000: sc_result = (op[3] ? op1 + (~op2+1) : op1 + op2); // ADD,SUB
        3'b001: sc_result = (op1 << op2[4:0]); // SLL
        3'b010: sc_result = {31'b0,$signed(op1) < $signed(op2)}; // SLT
        3'b011: sc_result = {31'b0,op1 < op2}; // SLTU
        3'b100: sc_result = (op[3] ? {31'b0,op1 == op2} : (op1 ^ op2)); // XOR, SEQ
        3'b101: sc_result = (op[3] ? $signed($signed(op1) >>> op2[4:0]) : (op1 >> op2[4:0])); // SRL, SRA
        3'b110: sc_result = (op1 | op2);
        3'b111: sc_result = (op1 & op2);
      endcase
    end
    // ALU Extensions
    else if (~op[0])
      // Priority Find: Encoder
      sc_result = {~|p_vector, 26'b0 , p_index};
    else
      // Priority Clear
      sc_result = op1 ^ p_vector;
  end

endmodule
