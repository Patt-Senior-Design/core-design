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
  input [31:0]  rename_imm,

  // wb interface
  output            csr_valid,  // Used as stall for 1 cycle at rename
  output reg        csr_error,
  output     [4:0]  csr_ecause,
  output     [6:0]  csr_robid,
  output     [5:0]  csr_rd,
  output reg [31:0] csr_result,

  // rob interface
  input         rob_flush,
  input         rob_ret_valid,
  input         rob_csr_valid,
  input [31:2]  rob_csr_epc,
  input [4:0]   rob_csr_ecause,
  input [31:0]  rob_csr_tval,
  output [31:2] csr_tvec);

  localparam
    MCYCLE    = 32'h0B00,
    MINSTRET  = 32'h0B02,
    MCYCLEH   = 32'h0B80,
    MINSTRETH = 32'h0B82;

  // Supported CSRs
  reg [31:0] mcycle;
  reg [31:0] mcycleh;
  reg [31:0] minstret;
  reg [31:0] minstreth;

  // Updated CSR value
  reg [31:0] mcycle_n; 
  reg [31:0] mcycleh_n;
  reg [31:0] minstret_n;
  reg [31:0] minstreth_n;

  reg valid;
  reg [2:0] op;
  reg [6:0] robid;
  reg [5:0] rd;
  reg [31:0] op1;
  reg [11:0] addr;

  assign csr_valid = valid;
  assign csr_robid = robid;
  assign csr_rd = rd;
  // CSR Errors: TBD
  assign csr_ecause = 0;

  // Returns write value (either passive or updated using csr instruction).
  // Sets read value
  function automatic [31:0] read_update (input[31:0] csr_cur_val);
    begin
      // Write logic
      if (valid) begin
        casez(op[1:0]) 
          2'b01:  read_update = op1;                  // CSRRW
          2'b10:  read_update = (csr_cur_val | op1);  // CSRRS 
          2'b11:  read_update = (csr_cur_val & ~op1); // CSRRC
          default:  read_update = 32'bx;
        endcase
      end
      // Read logic
      csr_result = csr_cur_val;
    end
  endfunction

  // Stage latches
  always @(posedge clk) begin
    valid <= rename_csr_write & (~valid);
    op <= rename_op[2:0];
    robid <= rename_robid;
    rd <= rename_rd;
    op1 <= rename_op1;
    addr <= rename_imm[11:0];
  end

  // CSR latching
  always @(posedge clk) begin
    mcycle <= mcycle_n;
    mcycleh <= mcycleh_n;
    minstret <= minstret_n;
    minstreth <= minstreth_n;  
  end

  // Update CSR logic
  always @(*) begin
    // Passive updates
    mcycle_n = mcycle + 1;
    mcycleh_n = mcycleh_n + (|mcycle);
    minstret_n = minstret + rob_ret_valid;
    minstreth_n = minstreth_n + (|minstret & rob_ret_valid);

    // Active updates: CSR instructions (overrides passive)
    csr_error = 0;
    casez(addr) 
      MCYCLE:     mcycle_n    = read_update (mcycle);
      MCYCLEH:    mcycleh_n   = read_update (mcycleh);
      MINSTRET:   minstret_n  = read_update (minstret);
      MINSTRETH:  minstret_n  = read_update (minstreth);
      default: begin
        csr_error = 1;  // Undefined CSR
        csr_result = 32'bx;
      end
    endcase

  end

endmodule
