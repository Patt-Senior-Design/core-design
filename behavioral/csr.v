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
  input [6:0]   rob_csr_head,
  input [31:2]  rob_csr_epc,
  input [4:0]   rob_csr_ecause,
  input [31:0]  rob_csr_tval,
  output [31:2] csr_tvec);

  localparam
    MCYCLE    = 12'hB00,
    MINSTRET  = 12'hB02,
    MCYCLEH   = 12'hB80,
    MINSTRETH = 12'hB82;

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

  // Sets read value. Returns write value (either passive or updated using csr instruction).
  /* NOTE: Doesn't work in simulation for some strange reason.. ಠ_ಠ */
  /*function automatic [31:0] read_update (input[31:0] csr_cur_val, input write, input funct2);
    begin
      // Write logic
      if (write) begin
        casez(funct2) 
          2'b01:  read_update = op1;                  // CSRRW
          2'b10:  read_update = (csr_cur_val | op1);  // CSRRS 
          2'b11:  read_update = (csr_cur_val & ~op1); // CSRRC
          default:  read_update = 32'hDEADBEEF;
        endcase
      end
      csr_result = csr_cur_val; // Read
    end
  endfunction*/

  // Stage latches: ROBID only latched when valid to handle minstret
  always @(posedge clk) begin
    valid <= rename_csr_write & (~valid);
    op <= rename_op[2:0];
    rd <= rename_rd;
    op1 <= rename_op1;
    addr <= rename_imm[11:0];
    if (rename_csr_write & (~valid))
      robid <= rename_robid;
  end

  // CSR latching
  always @(posedge clk) begin
    mcycle <= mcycle_n;
    mcycleh <= mcycleh_n;
    minstret <= minstret_n;
    minstreth <= minstreth_n;  
    /* For Simulation Only */
    if (rst) begin
      mcycle <= 0;
      mcycleh <= 0;
      minstret <= 0;
      minstreth <= 0;
    end
  end

  // Update CSR logic
  always @(*) begin
    // Passive updates
    {mcycleh_n, mcycle_n} = {mcycleh, mcycle} + 1;
    {minstreth_n, minstret_n} = {minstreth, minstret} + (rob_ret_valid & (rob_csr_head !== robid));

    // Active updates: CSR instructions (overrides passive)
    csr_error = 0;
    case(addr) 
      MCYCLE:   // mcycle_n = read_update (mcycle, valid, op[1:0]);
                begin  
                  if (valid) begin
                    casez(op[1:0]) 
                      2'b01:  mcycle_n = op1;             // CSRRW
                      2'b10:  mcycle_n = (mcycle | op1);  // CSRRS 
                      2'b11:  mcycle_n = (mcycle & ~op1); // CSRRC
                      default:  mcycle_n = 32'hDEADBEEF;
                    endcase
                    csr_result = mcycle;
                  end
                end
      MCYCLEH:  //  mcycleh_n   = read_update (mcycleh);
                begin  
                  if (valid) begin
                    casez(op[1:0]) 
                      2'b01:  mcycleh_n = op1;             // CSRRW
                      2'b10:  mcycleh_n = (mcycleh | op1);  // CSRRS 
                      2'b11:  mcycleh_n = (mcycleh & ~op1); // CSRRC
                      default:  mcycleh_n = 32'hDEADBEEF;
                    endcase
                    csr_result = mcycleh;
                  end
                end
      MINSTRET: //  minstret_n  = read_update (minstret);
                begin  
                  if (valid) begin
                    casez(op[1:0]) 
                      2'b01:  minstret_n = op1;             // CSRRW
                      2'b10:  minstret_n = (minstret | op1);  // CSRRS 
                      2'b11:  minstret_n = (minstret & ~op1); // CSRRC
                      default:  minstret_n = 32'hDEADBEEF;
                    endcase
                    csr_result = minstret;
                  end
                end
      MINSTRETH: // minstreth_n  = read_update (minstreth);
                begin  
                  if (valid) begin
                    casez(op[1:0]) 
                      2'b01:  minstreth_n = op1;             // CSRRW
                      2'b10:  minstreth_n = (minstreth | op1);  // CSRRS 
                      2'b11:  minstreth_n = (minstreth & ~op1); // CSRRC
                      default:  minstreth_n = 32'hDEADBEEF;
                    endcase
                    csr_result = minstreth;
                  end
                end
      default: begin
        csr_error = 1;  // Undefined CSR
        csr_result = 32'bx;
      end
    endcase

  end

endmodule
