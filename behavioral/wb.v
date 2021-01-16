// writeback (common data bus)
module wb(
  input         clk,
  input         rst,

  // scalu0 interface
  input         scalu0_valid,
  input         scalu0_error,
  input [4:0]   scalu0_ecause,
  input [7:0]   scalu0_robid,
  input [5:0]   scalu0_rd,
  input [31:0]  scalu0_result,
  output        wb_scalu0_stall,

  // scalu1 interface
  input         scalu1_valid,
  input         scalu1_error,
  input [4:0]   scalu1_ecause,
  input [7:0]   scalu1_robid,
  input [5:0]   scalu1_rd,
  input [31:0]  scalu1_result,
  output        wb_scalu1_stall,

  // mcalu0 interface
  input         mcalu0_valid,
  input         mcalu0_error,
  input [4:0]   mcalu0_ecause,
  input [7:0]   mcalu0_robid,
  input [5:0]   mcalu0_rd,
  input [31:0]  mcalu0_result,
  output        wb_mcalu0_stall,

  // mcalu1 interface
  input         mcalu1_valid,
  input         mcalu1_error,
  input [4:0]   mcalu1_ecause,
  input [7:0]   mcalu1_robid,
  input [5:0]   mcalu1_rd,
  input [31:0]  mcalu1_result,
  output        wb_mcalu1_stall,

  // lsq interface
  input         lsq_wb_valid,
  input         lsq_wb_error,
  input [4:0]   lsq_wb_ecause,
  input [7:0]   lsq_wb_robid,
  input [5:0]   lsq_wb_rd,
  input [31:0]  lsq_wb_result,
  output        wb_lsq_stall,

  // csr interface
  input         csr_valid,
  input         csr_error,
  input [4:0]   csr_ecause,
  input [7:0]   csr_robid,
  input [5:0]   csr_rd,
  input [31:0]  csr_result,

  // common output signals
  output        wb_valid,
  output        wb_error,
  output [4:0]  wb_ecause,
  output [7:0]  wb_robid,
  output [5:0]  wb_rd,
  output [31:0] wb_result,

  // rob interface
  input         rob_flush);

  assign wb_valid = 0;

endmodule
