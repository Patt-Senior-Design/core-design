// csr (control and status register) unit
module csr(
  input         clk,
  input         rst,

  // rename interface
  input         rename_csr_write,
  input [4:0]   rename_op,
  input [6:0]   rename_robid,
  input [5:0]   rename_rd,
  input [31:0]  rename_op1,
  input [31:0]  rename_op2,

  // wb interface
  output        csr_valid,
  output        csr_error,
  output [4:0]  csr_ecause,
  output [6:0]  csr_robid,
  output [5:0]  csr_rd,
  output [31:0] csr_result,

  // rob interface
  input         rob_flush,
  input         rob_csr_valid,
  input [31:2]  rob_csr_epc,
  input [4:0]   rob_csr_ecause,
  input [31:0]  rob_csr_tval,
  output [31:2] csr_tvec);

  assign csr_valid = 0;

endmodule
