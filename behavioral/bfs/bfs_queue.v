`include "buscmd.vh"

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
  output       spill_done,
  output       spill_op,
  output [63:0] spill_data,

  // cache interface
  input       dc_valid,
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

  wire restore_valid;
  assign restore_valid = dc_valid & (dc_op == `OP_RD);

  wire spill_cond;
  assign spill_cond = outq_sat & inq_full;

  always @(posedge clk) begin
    if (bfs_rst) begin
      qstate <= CORE;
      ct <= 0;
    end else begin
      qstate <= next_qstate;
      ct <= next_ct;
    end
  end

  wire single_final;
  assign single_final = dc_rbuf_empty & inq_empty & mq_empty & ~outq_filled & ~outq_empty;

  always @(*) begin
    outq_deq_req = 0;
    inq_enq_req = 0;
    inq_enq_data = 0;
    next_qstate = qstate;
    next_ct = ct;
    case(qstate)
      CORE: begin
        // FORWARDING
        outq_deq_req = ~inq_full & (outq_filled | single_final);
        inq_enq_req = outq_deq_req ? {~single_final, 1'b1} : 2'b00;
        inq_enq_data = outq_deq_data;
        // Spill only when inq full and outq saturated, restore when queues empty
        case(1)
          spill_cond: next_qstate = INIT_SPILL;
          pend_empty: next_qstate = INIT_RESTORE;
        endcase
      end
      INIT_SPILL: begin
        next_ct = 6;
        outq_deq_req = dc_ready;
        if(dc_ready)
          next_qstate = SPILL;
      end
      INIT_RESTORE: begin
        next_ct = 7;
        if(dc_ready)
          next_qstate = RESTORE;
      end
      RESTORE: begin
        next_ct = dc_valid ? (ct - 1) : ct;
        inq_enq_req = {2{dc_valid}};
        inq_enq_data = dc_rdata;
        if(dc_valid & (ct == 0))
          next_qstate = CORE;
      end
      SPILL: begin
        next_ct = dc_ready ? (ct - 1) : ct;
        outq_deq_req = dc_ready;
        if(dc_ready & (ct == 0))
          next_qstate = CORE;
      end
      default:
        next_qstate = CORE;
    endcase
  end

  assign queue_full = mq_full; // Debugging
  assign rqueue_empty = mq_empty & inq_empty;
  assign pend_empty = active & inq_empty & mq_empty & outq_empty & dc_rbuf_empty;
  
  assign spill_req = (qstate == INIT_SPILL) | (qstate == INIT_RESTORE) | (qstate == SPILL);
  assign spill_done = (ct == 0) & (((qstate == SPILL) & dc_ready) | ((qstate == RESTORE) & dc_valid));
  assign spill_op = qstate[0]; // 0 for spill, 1 for restore
  assign spill_data = outq_deq_data;

  assign rdata_out = mq_empty ? inq_deq_data : mq_deq_data;

endmodule 
