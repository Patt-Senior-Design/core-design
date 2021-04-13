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

  // Supported CSRs
  wire [31:0] mcycle; 
  wire [31:0] mcycleh;
  wire [31:0] minstret;
  wire [31:0] minstreth;
  wire [7:0] muarttx;

  // Updated CSR value
  wire [31:0] mcycle_n; 
  wire [31:0] mcycleh_n;
  wire [31:0] minstret_n;
  wire [31:0] minstreth_n;



  // Stage latches
  wire valid;
  flop #(1) valid_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(~csr_stall),
      .d(rename_csr_write), .q(valid));

  wire [2:0] op;
  wire [6:0] robid;
  wire [5:0] rd;
  wire [31:0] op1;
  wire [11:0] addr;
  wire stage_en = ~csr_stall & rename_csr_write;

  flop #(3) op_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(stage_en),
      .d(rename_op[2:0]), .q(op));
  flop #(7) robid_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(stage_en),
      .d(rename_robid), .q(robid));
  flop #(6) rd_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(stage_en),
      .d(rename_rd), .q(rd));
  flop #(32) op1_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(stage_en),
      .d(rename_op1), .q(op1));
  flop #(12) addr_flop (.clk(clk), .set(1'b0), .rst(1'b0), .enable(stage_en),
      .d(rename_imm[11:0]), .q(addr));

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
  wire sel_muarttx    = ~|(addr ^ MUARTTX);
  wire sel_bfs       = ~|(addr[11:4] ^ 8'h7D);
  wire sel_ml2stat    = ~|(addr ^ ML2STAT);
  wire sel_none = ~(sel_mcycle | sel_mcycleh | sel_minstret | sel_minstreth |
      sel_muartstat | sel_muartrx | sel_muarttx | sel_bfs | sel_ml2stat);

  // read-data mux
  premux #(32, 8) csr_result_mux (
      .sel ({sel_mcycle, sel_mcycleh, sel_minstret, sel_minstreth, sel_muartstat, 
             sel_muarttx, sel_bfs, sel_ml2stat}),
      .in  ({mcycle, mcycleh, minstret, minstreth, (MUARTSTAT_TXEMPTY | MUARTSTAT_RXEMPTY), 
            {24'b0, muarttx}, bfs_csr_rdata, {31'b0,l2fifo_l2_req}}),
      .out (csr_result)
  );


  // write data mux
  wire wen    = |op[1:0] & valid;
  wire csr_ro   = &addr[11:10];
  wire wr_error = |op[1:0] & csr_ro;

  wire [31:0] wdata;
  mux #(32, 4) wdata_mux (
      .sel(op[1:0]),
      .in({csr_result&~op1, csr_result|op1, op1, 32'b0}),
      .out(wdata));

  // set bfs req
  wire bfs_req_r;
  flop #(1) bfs_req_r_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(1'b1),
      .d(csr_bfs_valid), .q(bfs_req_r));

  // l2 fifo
  wire l2fifo_stall = wen & sel_ml2stat & l2fifo_l2_req;
  wire l2fifo_stall_r;
  flop #(1) l2fifo_stall_r_flop (.clk(clk), .set(wen&sel_ml2stat), .rst(rst|~l2fifo_l2_req), .enable(1'b0),
      .d(1'b0), .q(l2fifo_stall_r));

  // csrrs/c not supported
  assign csr_bfs_valid = valid & ~op[1] & sel_bfs & ~bfs_req_r;
  assign csr_bfs_addr = addr[3:0];
  assign csr_bfs_wen = wen;
  assign csr_bfs_wdata = op1;

  assign csr_stall = csr_bfs_valid | l2fifo_stall | l2fifo_stall_r;
  assign csr_error = sel_none | wr_error |
                     (bfs_req_r & (~bfs_csr_valid | bfs_csr_error));
  assign csr_ecause = 0; // TODO
  assign csr_tvec = 0;

  // CSR latching
  flop #(32) mcycle_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(1'b1), 
      .d(mcycle_n), .q(mcycle));
  flop #(32) mcycleh_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(1'b1),
      .d(mcycleh_n), .q(mcycleh));
  flop #(32) minstret_flop (.clk (clk), .set(1'b0), .rst(rst), .enable(1'b1),
      .d(minstret_n), .q(minstret));
  flop #(32) minstreth_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(1'b1),
      .d(minstreth_n), .q(minstreth));

  /* Update CSR logic */
  wire inc_minstret = rob_ret_valid & ~(rob_ret_csr & (addr == MINSTRET));

  // Passive csr update
  wire [63:0] mcycle64_n;
  `ADD (64, mcycle64_n, {mcycleh, mcycle}, 64'b1);

  wire [63:0] minstret64_n;
  `ADD (64, minstret64_n, {minstreth, minstret}, {63'b0, inc_minstret});

  // Next CSR: Passive:0, Active:1
   mux #(32, 2) mcycle_n_mux (
       .sel(sel_mcycle & wen),
       .in({wdata, mcycle64_n[31:0]}),
       .out(mcycle_n));

   mux #(32, 2) mcycleh_n_mux (
       .sel(sel_mcycleh & wen),
       .in ({wdata, mcycle64_n[63:32]}),
       .out (mcycleh_n));

   mux #(32, 2) minstret_n_mux (
       .sel(sel_minstret & wen),
       .in ({wdata, minstret64_n[31:0]}),
       .out (minstret_n));
    
   mux #(32, 2) minstreth_n_mux (
       .sel(sel_minstreth & wen),
       .in ({wdata, minstret64_n[63:32]}),
       .out (minstreth_n));

  // UART
  flop #(8) muarttx_flop (.clk(clk), .set(1'b0), .rst(rst), .enable(wen & sel_muarttx),
      .d(wdata[7:0]), .q(muarttx));

`ifndef SYNTHESIS
  /* TRACE */
  always @(posedge clk)
    if(valid & ~csr_error & wen)
      top.tb_trace_csr_write(
        robid,
        addr,
        wdata);

  always @(posedge clk)
    if(wen & sel_muarttx) begin
      top.tb_uart_tx(wdata[7:0]);
    end
`endif

endmodule
