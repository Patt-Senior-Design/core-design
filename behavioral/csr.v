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
  output        csr_stall,

  // wb interface
  output            csr_valid,
  output            csr_error,
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
  output [31:2] csr_tvec,

  // bfs interface
  output        csr_bfs_valid,
  output [3:0]  csr_bfs_addr,
  output        csr_bfs_wen,
  output [31:0] csr_bfs_wdata,
  input         bfs_csr_valid,
  input         bfs_csr_error,
  input [31:0]  bfs_csr_rdata);

  localparam
    MCYCLE    = 12'hB00,
    MINSTRET  = 12'hB02,
    MCYCLEH   = 12'hB80,
    MINSTRETH = 12'hB82,
    MUARTSTAT = 12'hFC0,
    MUARTRX   = 12'hFC1,
    MUARTTX   = 12'h7C0,
    MBFSSTAT  = 12'h7D0,
    MBFSROOT  = 12'h7D1,
    MBFSTARG  = 12'h7D2,
    MBFSQBASE = 12'h7D3,
    MBFSQSIZE = 12'h7D4;

  // uart status bits
  localparam
    MUARTSTAT_RXEMPTY = 32'h00000001,
    MUARTSTAT_RXFULL  = 32'h00000002,
    MUARTSTAT_TXEMPTY = 32'h00000004,
    MUARTSTAT_TXFULL  = 32'h00000008;

  // Supported CSRs
  reg [31:0] mcycle;
  reg [31:0] mcycleh;
  reg [31:0] minstret;
  reg [31:0] minstreth;
  reg [7:0]  muarttx;

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

  always @(posedge clk)
    if(rst)
      valid <= 0;
    else if(~csr_stall) begin
      valid <= rename_csr_write;
      if(rename_csr_write) begin
        op <= rename_op[2:0];
        rd <= rename_rd;
        op1 <= rename_op1;
        robid <= rename_robid;
        addr <= rename_imm[11:0];
      end
    end

  // address decoder
  reg sel_mcycle, sel_mcycleh;
  reg sel_minstret, sel_minstreth;
  reg sel_muartstat, sel_muartrx, sel_muarttx;
  reg sel_bfs;
  reg sel_none;
  always @(*) begin
    sel_mcycle = 0;
    sel_mcycleh = 0;
    sel_minstret = 0;
    sel_minstreth = 0;
    sel_muartstat = 0;
    sel_muartrx = 0;
    sel_muarttx = 0;
    sel_bfs = 0;
    sel_none = 0;
    casez(addr)
      MCYCLE: sel_mcycle = 1;
      MCYCLEH: sel_mcycleh = 1;
      MINSTRET: sel_minstret = 1;
      MINSTRETH: sel_minstreth = 1;
      MUARTSTAT: sel_muartstat = 1;
      MUARTRX: sel_muartrx = 1;
      MUARTTX: sel_muarttx = 1;
      12'h7D?: sel_bfs = 1;
      default: sel_none = 1;
    endcase
  end

  // read data mux
  always @(*)
    case(1)
      sel_mcycle: csr_result = mcycle;
      sel_mcycleh: csr_result = mcycleh;
      sel_minstret: csr_result = minstret;
      sel_minstreth: csr_result = minstreth;
      sel_muartstat: csr_result = MUARTSTAT_TXEMPTY | MUARTSTAT_RXEMPTY;
      sel_muarttx: csr_result = {24'b0,muarttx};
      sel_bfs: csr_result = bfs_csr_rdata;
      default: csr_result = 0;
    endcase

  // write data mux
  wire csr_ro;
  assign csr_ro = &addr[11:10];

  reg        wen;
  reg [31:0] wdata;
  reg        wr_error;
  always @(*) begin
    wen = valid;
    wdata = 0;
    wr_error = csr_ro;
    case(op[1:0])
      2'b00: begin
        wen = 0;
        wr_error = 0;
      end
      2'b01: wdata = op1;
      2'b10: wdata = csr_result | op1;
      2'b11: wdata = csr_result & ~op1;
    endcase
  end

  reg bfs_req_r;
  always @(posedge clk)
    if(rst)
      bfs_req_r <= 0;
    else
      bfs_req_r <= csr_bfs_valid;

  // csrrs/c not supported
  assign csr_bfs_valid = valid & ~op[1] & sel_bfs & ~bfs_req_r;
  assign csr_bfs_addr = addr[3:0];
  assign csr_bfs_wen = wen;
  assign csr_bfs_wdata = op1;

  assign csr_stall = csr_bfs_valid;
  assign csr_error = sel_none | wr_error |
                     (bfs_req_r & (~bfs_csr_valid | bfs_csr_error));
  assign csr_ecause = 0; // TODO

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
    {minstreth_n, minstret_n} = {minstreth, minstret} + (rob_ret_valid & (rob_csr_head !== robid) & 
                            (addr == MINSTRET));

    // Active updates: CSR instructions (overrides passive)
    if(wen)
      case(1)
        sel_mcycle: mcycle_n = wdata;
        sel_mcycleh: mcycleh_n = wdata;
        sel_minstret: minstret_n = wdata;
        sel_minstreth: minstreth_n = wdata;
      endcase
  end

  always @(posedge clk)
    if(valid & ~csr_error & wen)
      top.trace_csr_write(
        robid,
        addr,
        wdata);

  always @(posedge clk)
    if(wen & sel_muarttx) begin
      muarttx <= wdata;
      top.uart_tx(wdata);
    end

endmodule
