// writeback (common data bus)
// TBD: Merge all the interfaces into one array
module wb(
  input         clk,
  input         rst,

  // scalu0 interface
  input         scalu0_valid,
  input         scalu0_error,
  input [4:0]   scalu0_ecause,
  input [6:0]   scalu0_robid,
  input [5:0]   scalu0_rd,
  input [31:0]  scalu0_result,
  output reg    wb_scalu0_stall,

  // scalu1 interface
  input         scalu1_valid,
  input         scalu1_error,
  input [4:0]   scalu1_ecause,
  input [6:0]   scalu1_robid,
  input [5:0]   scalu1_rd,
  input [31:0]  scalu1_result,
  output reg    wb_scalu1_stall,

  // mcalu0 interface
  input         mcalu0_valid,
  input         mcalu0_error,
  input [4:0]   mcalu0_ecause,
  input [6:0]   mcalu0_robid,
  input [5:0]   mcalu0_rd,
  input [31:0]  mcalu0_result,
  output reg       wb_mcalu0_stall,

  // mcalu1 interface
  input         mcalu1_valid,
  input         mcalu1_error,
  input [4:0]   mcalu1_ecause,
  input [6:0]   mcalu1_robid,
  input [5:0]   mcalu1_rd,
  input [31:0]  mcalu1_result,
  output reg       wb_mcalu1_stall,

  // lsq interface
  input         lsq_wb_valid,
  input         lsq_wb_error,
  input [4:0]   lsq_wb_ecause,
  input [6:0]   lsq_wb_robid,
  input [5:0]   lsq_wb_rd,
  input [31:0]  lsq_wb_result,
  output reg       wb_lsq_stall,

  // csr interface
  input         csr_valid,
  input         csr_error,
  input [4:0]   csr_ecause,
  input [6:0]   csr_robid,
  input [5:0]   csr_rd,
  input [31:0]  csr_result,

  // common output signals
  output reg       wb_valid,
  output reg       wb_error,
  output reg[4:0]  wb_ecause,
  output reg[6:0]  wb_robid,
  output reg[5:0]  wb_rd,
  output reg[31:0] wb_result,

  // rob interface
  input         rob_flush);

  reg         scalu0_valid_r;
  reg         scalu0_error_r;
  reg [4:0]   scalu0_ecause_r;
  reg [6:0]   scalu0_robid_r;
  reg [5:0]   scalu0_rd_r;
  reg [31:0]  scalu0_result_r;

  reg         scalu1_valid_r;
  reg         scalu1_error_r;
  reg [4:0]   scalu1_ecause_r;
  reg [6:0]   scalu1_robid_r;
  reg [5:0]   scalu1_rd_r;
  reg [31:0]  scalu1_result_r;

  reg         mcalu0_valid_r;
  reg         mcalu0_error_r;
  reg [4:0]   mcalu0_ecause_r;
  reg [6:0]   mcalu0_robid_r;
  reg [5:0]   mcalu0_rd_r;
  reg [31:0]  mcalu0_result_r;

  reg         mcalu1_valid_r;
  reg         mcalu1_error_r;
  reg [4:0]   mcalu1_ecause_r;
  reg [6:0]   mcalu1_robid_r;
  reg [5:0]   mcalu1_rd_r;
  reg [31:0]  mcalu1_result_r;

  reg         lsq_valid_r;
  reg         lsq_error_r;
  reg [4:0]   lsq_ecause_r;
  reg [6:0]   lsq_robid_r;
  reg [5:0]   lsq_rd_r;
  reg [31:0]  lsq_result_r;

  reg [4:0] fu_valid;
  reg [4:0] fu_arbitrated;

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      scalu0_valid_r <= 1'b0;
      scalu1_valid_r <= 1'b0;
      mcalu0_valid_r <= 1'b0;
      mcalu1_valid_r <= 1'b0;
      lsq_valid_r <= 1'b0;
    end
    else begin
      // CSR uses scalu0
      if(~wb_scalu0_stall) begin
        scalu0_valid_r <= csr_valid | scalu0_valid;
        scalu0_error_r <= (csr_valid ? csr_error : scalu0_error);
        scalu0_ecause_r <= (csr_valid ? csr_ecause : scalu0_ecause);
        scalu0_robid_r <= (csr_valid ? csr_robid : scalu0_robid);
        scalu0_rd_r <= (csr_valid ? csr_rd : scalu0_rd);
        scalu0_result_r <= (csr_valid ? csr_result : scalu0_result);
      end

      if(~wb_scalu1_stall) begin
        scalu1_valid_r <= scalu1_valid;
        scalu1_error_r <= scalu1_error;
        scalu1_ecause_r <= scalu1_ecause;
        scalu1_robid_r <= scalu1_robid;
        scalu1_rd_r <= scalu1_rd;
        scalu1_result_r <= scalu1_result;
      end

      if(~wb_mcalu0_stall) begin
        mcalu0_valid_r <= mcalu0_valid;
        mcalu0_error_r <= mcalu0_error;
        mcalu0_ecause_r <= mcalu0_ecause;
        mcalu0_robid_r <= mcalu0_robid;
        mcalu0_rd_r <= mcalu0_rd;
        mcalu0_result_r <= mcalu0_result;
      end

      if(~wb_mcalu1_stall) begin
        mcalu1_valid_r <= mcalu1_valid;
        mcalu1_error_r <= mcalu1_error;
        mcalu1_ecause_r <= mcalu1_ecause;
        mcalu1_robid_r <= mcalu1_robid;
        mcalu1_rd_r <= mcalu1_rd;
        mcalu1_result_r <= mcalu1_result;
      end

      if(~wb_lsq_stall) begin
        lsq_valid_r <= lsq_wb_valid;
        lsq_error_r <= lsq_wb_error;
        lsq_ecause_r <= lsq_wb_ecause;
        lsq_robid_r <= lsq_wb_robid;
        lsq_rd_r <= lsq_wb_rd;
        lsq_result_r <= lsq_wb_result;
      end
    end
  end

  always @(*) begin
    fu_valid = {lsq_valid_r, mcalu1_valid_r, mcalu0_valid_r, scalu1_valid_r, scalu0_valid_r};
    wb_valid = (| fu_valid);
    casez(fu_valid)
      5'b1????: begin
                  fu_arbitrated = 5'b10000;
                  wb_error = lsq_error_r;
                  wb_ecause = lsq_ecause_r; 
                  wb_robid = lsq_robid_r;
                  wb_rd = lsq_rd_r;
                  wb_result = lsq_result_r;
                end
      5'b01???: begin 
                  fu_arbitrated = 5'b01000;
                  wb_error = mcalu1_error_r;
                  wb_ecause = mcalu1_ecause_r; 
                  wb_robid = mcalu1_robid_r;
                  wb_rd = mcalu1_rd_r;
                  wb_result = mcalu1_result_r;
                end
      5'b001??: begin 
                  fu_arbitrated = 5'b00100;
                  wb_error = mcalu0_error_r;
                  wb_ecause = mcalu0_ecause_r; 
                  wb_robid = mcalu0_robid_r;
                  wb_rd = mcalu0_rd_r;
                  wb_result = mcalu0_result_r;
                end
      5'b0001?: begin 
                  fu_arbitrated = 5'b00010;
                  wb_error = scalu1_error_r;
                  wb_ecause = scalu1_ecause_r; 
                  wb_robid = scalu1_robid_r;
                  wb_rd = scalu1_rd_r;
                  wb_result = scalu1_result_r;
                end
      5'b00001: begin 
                  fu_arbitrated = 5'b00001;
                  wb_error = scalu0_error_r;
                  wb_ecause = scalu0_ecause_r; 
                  wb_robid = scalu0_robid_r;
                  wb_rd = scalu0_rd_r;
                  wb_result = scalu0_result_r;
                end
      default:  begin
                  wb_valid = 1'b0;
                  fu_arbitrated = 5'b00000;
                end
    endcase
    {wb_lsq_stall, wb_mcalu1_stall, wb_mcalu0_stall, 
      wb_scalu1_stall, wb_scalu0_stall} = (fu_valid & (~fu_arbitrated));
  end

endmodule
