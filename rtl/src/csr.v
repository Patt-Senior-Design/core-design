`include "rtldefs.vh"
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
  output     [31:0] csr_result,

  // rob interface
  input         rob_flush,
  input         rob_ret_valid,
  input         rob_ret_csr,
  input         rob_csr_valid,
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
  input [31:0]  bfs_csr_rdata,

  // l2fifo interface
  input         l2fifo_l2_req);

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
    MBFSQSIZE = 12'h7D4,
    ML2STAT   = 12'h7E0;

  // uart status bits
  localparam
    MUARTSTAT_RXEMPTY = 32'h00000001,
    MUARTSTAT_RXFULL  = 32'h00000002,
    MUARTSTAT_TXEMPTY = 32'h00000004,
    MUARTSTAT_TXFULL  = 32'h00000008;


  wire [31:0] wdata;
  wire wen;

  // Updated CSR value
  wire [31:0] mcycle_n; 
  wire [31:0] mcycleh_n;
  wire [31:0] minstret_n;
  wire [31:0] minstreth_n;

  // Supported CSRs/latching
  `FLOP (mcycle, 32, mcycle_n);
  `FLOP (mcycleh, 32, mcycleh_n);
  `FLOP (minstret, 32, minstret_n);
  `FLOP (minstreth, 32, minstreth_n);

  // UART
  wire sel_muarttx;
  `FLOP_E (muarttx, 8, wen & sel_muarttx, wdata[7:0]);


  // Stage latches
  wire stage_en = ~csr_stall & rename_csr_write;
  `FLOP_E   (valid, 1, ~csr_stall, rename_csr_write);
  `FLOP_NRE (op, 3, stage_en, rename_op[2:0]);
  `FLOP_NRE (rd, 6, stage_en, rename_rd);
  `FLOP_NRE (op1, 32, stage_en, rename_op1);
  `FLOP_NRE (robid, 7, stage_en, rename_robid);
  `FLOP_NRE (addr, 12, stage_en, rename_imm[11:0]);
  
  assign csr_valid = valid & ~csr_stall;
  assign csr_robid = robid;
  assign csr_rd = rd;

  // address decoder
  wire sel_mcycle     = ~|(addr ^ MCYCLE);
  wire sel_mcycleh    = ~|(addr ^ MCYCLEH);
  wire sel_minstret   = ~|(addr ^ MINSTRET);
  wire sel_minstreth  = ~|(addr ^ MINSTRETH);
  wire sel_muartstat  = ~|(addr ^ MUARTSTAT);
  wire sel_muartrx    = ~|(addr ^ MUARTRX);
  assign sel_muarttx    = ~|(addr ^ MUARTTX);
  wire sel_bfs       = ~|(addr[11:4] ^ 8'h7D);
  wire sel_ml2stat    = ~|(addr ^ ML2STAT);
  wire sel_none = ~(sel_mcycle | sel_mcycleh | sel_minstret | sel_minstreth |
      sel_muartstat | sel_muartrx | sel_muarttx | sel_bfs | sel_ml2stat);

  // read-data mux
  wire [31:0] sel_mcycle_out     = (mcycle & {32{sel_mcycle}});
  wire [31:0] sel_mcycleh_out    = (mcycleh & {32{sel_mcycleh}});
  wire [31:0] sel_minstret_out   = (minstret & {32{sel_minstret}});
  wire [31:0] sel_minstreth_out  = (minstreth & {32{sel_minstreth}});
  wire [31:0] sel_muartstat_out  = ((MUARTSTAT_TXEMPTY | MUARTSTAT_RXEMPTY) & {32{sel_muartstat}});
  //wire [31:0] sel_muartrx_out    = (mcycle & {32{sel_muartrx}});
  wire [31:0] sel_muarttx_out    = ({24'b0,muarttx} & {32{sel_muarttx}});
  wire [31:0] sel_bfs_out       = (bfs_csr_rdata & {32{sel_bfs}});
  wire [31:0] sel_ml2stat_out    = ({31'b0,l2fifo_l2_req} & {32{sel_ml2stat}});

  assign csr_result = (sel_mcycle_out | sel_mcycleh_out | sel_minstret_out | sel_minstreth_out |
      sel_muartstat_out | sel_muarttx_out | sel_bfs_out | sel_ml2stat_out);

  // write data mux
  assign wen    = |op[1:0] & valid;
  wire csr_ro   = &addr[11:10];
  wire wr_error = |op[1:0] & csr_ro;
  `MUX4X1 (wdata, 32, op[1:0], 
          0, op1, csr_result|op1, csr_result&~op1)

  // set bfs req
  `FLOP (bfs_req_r, 1, csr_bfs_valid);

  // l2 fifo
  wire l2fifo_stall = wen & sel_ml2stat & l2fifo_l2_req;
  `FLOP_RS (l2fifo_stall_r, 1, rst|~l2fifo_l2_req, wen&sel_ml2stat);

  // csrrs/c not supported
  assign csr_bfs_valid = valid & ~op[1] & sel_bfs & ~bfs_req_r;
  assign csr_bfs_addr = addr[3:0];
  assign csr_bfs_wen = wen;
  assign csr_bfs_wdata = op1;

  assign csr_stall = csr_bfs_valid | l2fifo_stall | l2fifo_stall_r;
  assign csr_error = sel_none | wr_error |
                     (bfs_req_r & (~bfs_csr_valid | bfs_csr_error));
  assign csr_ecause = 0; // TODO


  /* Update CSR logic */
  wire inc_minstret;
  assign inc_minstret = rob_ret_valid & ~(rob_ret_csr & (addr === MINSTRET));

  wire [63:0] mcycle64_n;
  wire [63:0] minstret64_n;
  // Passive csr update
  `ADD (64, mcycle64_n, {mcycleh, mcycle}, 64'b1);
  `ADD (64, minstret64_n, {minstreth, minstret}, {63'b0, inc_minstret});

  // Next CSR: Passive:0, Active:1
  `MUX2X1 (mcycle_n,    32, sel_mcycle & wen    , mcycle64_n[31:0]    , wdata);
  `MUX2X1 (mcycleh_n,   32, sel_mcycleh & wen   , mcycle64_n[63:32]   , wdata);
  `MUX2X1 (minstret_n,  32, sel_minstret & wen  , minstret64_n[31:0]  , wdata);
  `MUX2X1 (minstreth_n, 32, sel_minstreth & wen , minstret64_n[63:32] , wdata);

  // =====

  /* TRACE */
  always @(posedge clk)
    if(valid & ~csr_error & wen)
      top.tb_trace_csr_write(
        robid,
        addr,
        wdata);

  always @(posedge clk)
    if(wen & sel_muarttx) begin
      //muarttx <= wdata;
      top.tb_uart_tx(wdata[7:0]);
    end

endmodule
