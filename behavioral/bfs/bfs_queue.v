module bfs_queue #(
  parameter Q_SIZE = 128
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

  reg [31:0]      buf_addr0[Q_SIZE-1:0];
  reg [31:0]      buf_addr1[Q_SIZE-1:0];
  reg [Q_SIZE-1:0] buf_valid0;
  reg [Q_SIZE-1:0] buf_valid1;

  wire [$clog2(Q_SIZE)-1:0] enq_idx;
  assign enq_idx = bfs_rst ? 0 : buf_tail;

  // Enqueue[0]: low 32 bits of wdata_in; Enqueue[1]: high 32 bits of wdata_in
  always @(posedge clk) begin
    if (bfs_rst) begin 
      buf_valid0 <= 0;
      buf_valid1 <= 0;
    end else if (dequeue_req & ~queue_empty) begin  // Dequeuing
      buf_valid0[buf_head] <= 0;
      if (head_single)
        buf_valid1[buf_head] <= 0; 
    end
    // Enqueuing happens along with bfs_rst for initial insertion of from node
    if (|enqueue_req & (~queue_full | bfs_rst)) begin
      {buf_valid0[enq_idx], buf_valid1[enq_idx]} <= enqueue_req;
      buf_addr0[enq_idx] <= wdata_in[63:32];
      buf_addr1[enq_idx] <= wdata_in[31:0];
    end
  end


  wire [$clog2(Q_SIZE):0]  buf_head_next, buf_tail_next;
  reg [$clog2(Q_SIZE)-1:0] buf_head, buf_tail;
  reg                     buf_head_pol, buf_tail_pol;
  wire                    head_single;
  assign head_single = ~buf_valid0[buf_head] & buf_valid1[buf_head];

  assign buf_tail_next = (|enqueue_req & ~queue_full) ? 
                            {buf_tail_pol, buf_tail} + 1 : {buf_tail_pol, buf_tail};
  assign buf_head_next = (dequeue_req & ~queue_empty & head_single) ? 
                            {buf_head_pol, buf_head} + 1 : {buf_head_pol, buf_head};

  // buf sequencing
  always @(posedge clk) begin
    if (bfs_rst) begin
      {buf_head_pol, buf_head} <= 0;
      {buf_tail_pol, buf_tail} <= |enqueue_req ? 1 : 0; // Initial insertion of from node
    end else begin
      {buf_head_pol, buf_head} <= buf_head_next;
      {buf_tail_pol, buf_tail} <= buf_tail_next;
    end
  end


  wire wraparound = (buf_head_pol ^ buf_tail_pol);
  wire pt_eq = (buf_head === buf_tail);

  assign rdata_out = buf_valid0[buf_head] ? buf_addr0[buf_head] : buf_addr1[buf_head];
  assign queue_full = (wraparound & pt_eq);
  assign queue_empty = (~wraparound & pt_eq);


 endmodule 