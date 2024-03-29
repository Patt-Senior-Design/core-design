module test_bfs;
  reg clk;
  reg rst;

  wire bfs_dc_req;
  wire[1:0] bfs_dc_op;
  wire[31:0] bfs_dc_addr;
  wire dc_ready;
  wire dc_rbuf_empty;
  wire dc_fs;
  wire [1:0] dc_op;
  wire[63:0] bfs_dc_wdata;
  wire[63:0] dc_rdata;

  bfs_cache cache (
    .clk (clk),
    .rst (rst),
    .bfs_dc_req (bfs_dc_req),
    .bfs_dc_op (bfs_dc_op),
    .bfs_dc_addr (bfs_dc_addr),
    .dc_ready (dc_ready),
    .dc_rbuf_empty (dc_rbuf_empty),
    .bfs_dc_wdata (bfs_dc_wdata),
    .dc_fs (dc_fs),
    .dc_op (dc_op),
    .dc_rdata (dc_rdata));

  // Rename
  reg bfs_write;
  reg [5:0] bfs_rd;
  reg [6:0] bfs_robid;
  reg [31:0] from_node, to_node;
  wire stall;
  
  // Writeback
  wire wb_valid, wb_error;
  wire [4:0] wb_ecause;
  wire [6:0] wb_robid;
  wire [5:0] wb_rd;
  wire [31:0] wb_result;
  reg wb_bfs_stall;
  
  // Rob
  reg rob_flush;

  bfs_core core (
    .clk (clk), 
    .rst (rst),
    .rename_bfs_write (bfs_write),
    .rename_robid (bfs_robid),
    .rename_rd (bfs_rd),
    .rename_op1 (from_node),
    .rename_op2 (to_node),
    .bfs_stall (stall),

    .bfs_valid (wb_valid),
    .bfs_error (wb_error),
    .bfs_ecause (wb_ecause),
    .bfs_robid (wb_robid),
    .bfs_rd (wb_rd),
    .bfs_result (wb_result),
    .wb_bfs_stall (wb_bfs_stall),

    .bfs_dc_req (bfs_dc_req),
    .bfs_dc_op (bfs_dc_op),
    .bfs_dc_addr (bfs_dc_addr),
    .bfs_dc_wdata (bfs_dc_wdata),
    .dc_ready (dc_ready),
    .dc_op (dc_op),
    .dc_rbuf_empty (dc_rbuf_empty),
    .dc_fs (dc_fs),
    .dc_rdata (dc_rdata),

    .rob_flush (rob_flush));

  always #5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
    $dumplimit(32*1024*1024);

    if (!$value$plusargs("from=%d", from_node) || !$value$plusargs("to=%d", to_node)) begin
      from_node = 32'h00C0; // Node 3: base_addr = 0
      to_node = 32'h0080; // Node 2: base_addr = 0
    end else begin
      from_node = from_node << 6;
      to_node = to_node << 6;
    end

    clk = 0;
    rob_flush = 0;
    rst = 1;
    #30;

    rst = 0; // Run
    bfs_write = 1;
    bfs_rd = 14;
    bfs_robid = 65;
    #20;

    bfs_write = 0; // Not run
    bfs_rd = 7;
    bfs_robid = 3;
    from_node = 32'h0100; // Node 4
    to_node = 32'h0140; // Node 5
    @(posedge wb_valid);
    #60000;

    rst = 1;
    #10;
    rst = 0;
    bfs_write = 1;
    #10;
    bfs_write = 0;
    @(posedge wb_valid);
    #20000;
    $finish;
  end

endmodule
