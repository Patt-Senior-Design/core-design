module bfs_queue #(
  parameter MAINQ_SIZE = 128,
  parameter BUFQ_SIZE = 64
  )(
  input        clk,
  input        bfs_rst,

  // core interface
  input        active,
  input [1:0]  enqueue_req,
  input [63:0] wdata_in,
  input        dequeue_req,
  output [31:0] rdata_out,
  output       queue_full,
  output       rqueue_empty,
  output       pend_empty,
  // spill signals
  output       spill_req,
  output       spill_op,
  output [63:0] spill_data,

  // cache interface
  input       dc_fs,
  input [1:0] dc_op,
  input       dc_ready,
  input [63:0]  dc_rdata,
  input       dc_rbuf_empty);

  localparam
    CORE = 3'b000,
    INIT_SPILL = 3'b010,
    SPILL = 3'b110,
    INIT_RESTORE = 3'b011,
    RESTORE = 3'b111;

  // Main Q: Enq from core, deq to core
  wire [1:0]  mq_enq_req;
  wire        mq_deq_req;
  wire [31:0] mq_deq_data;
  wire       mq_full;
  wire       mq_empty;

  // Out Q: Enq from core, deq to memory 
  wire [1:0]  outq_enq_req;
  reg        outq_deq_req;
  wire [63:0] outq_deq_data;
  wire        outq_filled;
  wire       outq_sat;
  wire       outq_full;
  wire       outq_empty;

  // In Q: Enq from memory, deq to core
  reg [1:0]  inq_enq_req;
  reg [63:0] inq_enq_data;
  wire        inq_deq_req;
  wire [31:0] inq_deq_data;
  wire       inq_full;
  wire       inq_empty;



  assign mq_enq_req = enqueue_req;
  assign mq_deq_req = dequeue_req;
  queue_main #(.Q_SIZE(MAINQ_SIZE)) main_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (mq_enq_req),
    .wdata_in (wdata_in),
    .dequeue_req (mq_deq_req),
    .rdata_out (mq_deq_data),
    .queue_full (mq_full),
    .queue_empty (mq_empty));

  assign outq_enq_req = (mq_full ? enqueue_req : 2'b00);
  //assign outq_deq_req = ~inq_full & ~outq_empty;
  queue_out #(.Q_SIZE(BUFQ_SIZE)) out_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (outq_enq_req),
    .wdata_in (wdata_in),
    .dequeue_req (outq_deq_req),
    .rdata_out (outq_deq_data),
    .rdata_filled(outq_filled),
    .queue_sat (outq_sat),
    .queue_full (outq_full),
    .queue_empty (outq_empty));

  assign inq_deq_req = (mq_empty ? dequeue_req : 1'b0);
  queue_main #(.Q_SIZE(BUFQ_SIZE)) in_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (inq_enq_req),
    .wdata_in (inq_enq_data),
    .dequeue_req (inq_deq_req),
    .rdata_out (inq_deq_data),
    .queue_full (inq_full),
    .queue_empty (inq_empty));


  /* State machine controller for spilling */
  reg[2:0] qstate, next_qstate;
  reg[2:0] ct, next_ct;
  reg spill_init;

  wire spill_fs;
  assign spill_fs = dc_fs & (dc_op[0]);

  wire spill_cond;
  assign spill_cond = outq_sat & inq_full;

  always @(posedge clk) begin
    if (bfs_rst) begin
      qstate <= CORE;
      ct <= 0;
      spill_init <= 0;
    end else begin
      qstate <= next_qstate;
      ct <= next_ct;
      // Spill gets priority over normal deq
      if (dc_ready)
        spill_init <= 0;
      if (next_qstate[1] & (qstate === CORE)) // If moving from core to init
        spill_init <= 1;
    end
  end

  always @(*) begin
    casez(qstate)
      CORE: begin
        // FORWARDING
        outq_deq_req = ~inq_full & (outq_filled | single_final);
        inq_enq_req = outq_deq_req ? {~single_final, 1'b1} : 2'b00;
        inq_enq_data = outq_deq_data;
        // Spill only when inq full and outq saturated, restore when queues empty
        casez({spill_cond, pend_empty})
          2'b00: next_qstate = CORE;
          2'b01: next_qstate = INIT_RESTORE;
          2'b10: next_qstate = INIT_SPILL;
        endcase
      end
      INIT_SPILL: begin
        next_ct = 6;
        outq_deq_req = spill_fs;
        next_qstate = (spill_fs ? SPILL : INIT_SPILL); 
      end
      INIT_RESTORE: begin
        next_ct = 6;
        inq_enq_req = {spill_fs, spill_fs};
        inq_enq_data = dc_rdata;
        next_qstate = (spill_fs ? RESTORE : INIT_RESTORE);
      end
      RESTORE: begin
        next_ct = ct - 1;
        inq_enq_req = 2'b11;
        inq_enq_data = dc_rdata;
        next_qstate = (ct ? RESTORE : CORE);
      end
      SPILL: begin
        next_ct = ct - 1;
        outq_deq_req = 1'b1;
        next_qstate = (ct ? SPILL : CORE);
      end
    endcase
  end

  wire single_final;
  assign single_final = dc_rbuf_empty & inq_empty & mq_empty & ~outq_filled & ~outq_empty;

  assign queue_full = mq_full; // Debugging
  assign rqueue_empty = mq_empty & inq_empty;
  assign pend_empty = active & inq_empty & mq_empty & outq_empty & dc_rbuf_empty;
  
  assign spill_req = spill_init & dc_ready;
  assign spill_op = qstate[0]; // 0 for spill, 1 for restore
  assign spill_data = outq_deq_data;

  assign rdata_out = mq_empty ? inq_deq_data : mq_deq_data;

endmodule 
