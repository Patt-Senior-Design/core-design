// Single Cycle ALU operations
module alu_simple(
  // exec unit interface
  input [4:0]       op,
  input [31:0]      op1,
  input [31:0]      op2,
  output [31:0] sc_result);

  wire [31:0] p_vector;
  wire [4:0] p_index;

  wire [31:0] vector = op1 & ~op2;
  wire [32*32-1:0] temp_vals;

  // Get priority result from vector
  wire [31:0] zero = 0;

  wire [31:0] last_bit_exp = 1 << 31;
  mux #(32, 2) last_bit_mux (.sel(vector[31]), .in({last_bit_exp, zero}), .out(temp_vals[32*32-1:32*31]));

  genvar j;
  for (j = 0; j < 31; j=j+1) begin
    wire [31:0] bit_exp = 1 << j;
    wire [31:0] next_bit_val = temp_vals[32*(j+2)-1:32*(j+1)];
    mux #(32, 2) bit_mux (.sel(vector[j]), .in({bit_exp, next_bit_val}), .out(temp_vals[32*(j+1)-1:32*j]));
  end

  assign p_vector = (|vector ? temp_vals[31:0] : 0);
  /*verilator lint_off WIDTH*/
  assign p_index = $clog2(p_vector);
  /*verilator lint_on WIDTH*/

  wire [31:0] add_or_sub;
  mux #(32, 2) add_or_sub_mux (.sel(op[3]), .in({(op1 + (~op2+1)), (op1 + op2)}), .out(add_or_sub));

  wire [31:0] sll = (op1 << op2[4:0]);
  wire [31:0] slt = {31'b0,$signed(op1) < $signed(op2)};
  wire [31:0] sltu = {31'b0,op1 < op2};
  wire [31:0] xor_or_seq = op[3] ? {31'b0,op1 == op2} : (op1 ^ op2);
  wire [31:0] srl_or_sra = op[3] ? $signed($signed(op1) >>> op2[4:0]) : (op1 >> op2[4:0]);
  wire [31:0] or_result = (op1 | op2);
  wire [31:0] and_result = (op1 & op2);

  wire [31:0] op_result;
  mux #(32, 8) op_result_mux (.sel(op[2:0]), .in({and_result, or_result, srl_or_sra, xor_or_seq, sltu, slt, sll, add_or_sub}), .out(op_result));

  wire [31:0] pfind_result = {~|p_vector, 26'b0, p_index};
  wire [31:0] pclear_result = op1 ^ p_vector;

  wire [31:0] priority_op_result;
  mux #(32, 2) priority_op_mux (.sel(~op[0]), .in({pfind_result, pclear_result}), .out(priority_op_result));

  mux #(32, 2) sc_result_mux (.sel(~op[4]), .in({op_result, priority_op_result}), .out(sc_result));

endmodule
