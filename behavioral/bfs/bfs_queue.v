module bfs_queue #(
  parameter MAINQ_SIZE = 128,
  parameter BUFQ_SIZE = 64
  )(
  input        clk,
  input        bfs_rst,

  // core interface
  input [1:0]  enqueue_req,
  input [63:0] wdata_in,
  input        dequeue_req,
  output [31:0] rdata_out,
  output       queue_full,
  output       queue_empty);


  // Main Q: Enq from core, deq to core
  wire [1:0]  mq_enq_req;
  wire        mq_deq_req;
  wire [31:0] mq_deq_data;
  wire       mq_full;
  wire       mq_empty;

  assign mq_enq_req = (~mq_full ? enqueue_req : 2'b00);
  assign mq_deq_req = (~mq_empty ? dequeue_req : 1'b0);

  queue_main #(.Q_SIZE(MAINQ_SIZE)) main_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (mq_enq_req),
    .wdata_in (wdata_in),
    .dequeue_req (mq_deq_req),
    .rdata_out (mq_deq_data),
    .queue_full (mq_full),
    .queue_empty (mq_empty));


  // Out Q: Enq from core, deq to memory 
  wire [1:0]  outq_enq_req;
  wire        outq_deq_req;
  wire [31:0] outq_deq_data;
  wire       outq_full;
  wire       outq_empty;

  assign outq_enq_req = (mq_full ? enqueue_req : 2'b00);
  assign outq_deq_req = ~inq_full & ~outq_empty;

  queue_tw #(.Q_SIZE(BUFQ_SIZE)) out_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (outq_enq_req),
    .wdata_in (wdata_in),
    .dequeue_req (outq_deq_req),
    .rdata_out (outq_deq_data),
    .queue_full (outq_full),
    .queue_empty (outq_empty));


  // In Q: Enq from memory, deq to core
  wire [1:0]  inq_enq_req;
  wire        inq_deq_req;
  wire [31:0] inq_deq_data;
  wire       inq_full;
  wire       inq_empty;

  assign inq_enq_req = 0;
  assign inq_deq_req = 0;

  queue_tw #(.Q_SIZE(BUFQ_SIZE)) in_q (
    .clk(clk),
    .bfs_rst(bfs_rst),
    .enqueue_req (inq_enq_req),
    .wdata_in (wdata_in),
    .dequeue_req (inq_deq_req),
    .rdata_out (inq_deq_data),
    .queue_full (inq_full),
    .queue_empty (inq_empty));


  assign queue_full = mq_full;
  assign queue_empty = mq_empty;
  assign rdata_out = mq_deq_data;

endmodule 
