// Supports dual enqueue and dual dequeue.
// Can enqueue to multiple rows, but dequeue from only one
module queue_out #(
  parameter Q_SIZE = 64
  )(
  input        clk,
  input        bfs_rst,

  // core interface
  input [1:0]  enqueue_req,
  input [63:0] wdata_in,
  input        dequeue_req,
  output [63:0] rdata_out,
  output [63:0] tail_data,
  output        rdata_filled,
  output       queue_full,
  output       queue_empty);

  // Main Queue
  reg [31:0]      buf_addr0[Q_SIZE-1:0];
  reg [31:0]      buf_addr1[Q_SIZE-1:0];
  reg [Q_SIZE-1:0] buf_valid0;
  reg [Q_SIZE-1:0] buf_valid01; // Set if both 0 and 1 valid

  // Determine whether to insert 0 at current/next row
  wire [$clog2(Q_SIZE)-1:0] buf_tail0;
  assign buf_tail0 = tail_single ? buf_tail_next[$clog2(Q_SIZE)-1:0] : buf_tail;

  // Enqueue[0]: low 32 bits of wdata_in; Enqueue[1]: high 32 bits of wdata_in
  always @(posedge clk) begin
    if (bfs_rst) begin 
      buf_valid0 <= 0;
      buf_valid01 <= 0;
    end else begin
      // Dequeuing: Always invalidate both
      if (dequeue_req & ~queue_empty) begin
        buf_valid01[buf_head] <= 0;
        buf_valid0[buf_head] <= 0;
      end
      // Enqueuing
      if (~queue_full) begin
        // Enqueue to 1
        if (advance_tail) begin
          buf_valid01[buf_tail] <= 1;
          buf_addr1[buf_tail] <= (tail_single ? wdata_in[31:0] : wdata_in[63:32]);
        end
        // Enqueue to 0
        if (enqueue_req[0] & (~tail_single | enqueue_req[1])) begin
          buf_valid0[buf_tail0] <= 1;
          buf_addr0[buf_tail0] <= (tail_single ? wdata_in[63:32] : wdata_in[31:0]);
        end
      end
    end
  end


  reg [$clog2(Q_SIZE)-1:0] buf_head, buf_tail;
  reg                     buf_head_pol, buf_tail_pol;


  wire [$clog2(Q_SIZE):0]  buf_head_next, buf_tail_next, bt;
  wire                    head_double;
  wire                    tail_single;
  wire                    advance_head;
  wire                    advance_tail; 

  assign head_double = buf_valid01[buf_head];
  assign advance_head = dequeue_req & head_double;

  assign tail_single = buf_valid0[buf_tail];
  assign advance_tail = (&enqueue_req | (|enqueue_req & tail_single));

  assign buf_tail_next = (~queue_full & advance_tail) ? 
                            {buf_tail_pol, buf_tail} + 1 : {buf_tail_pol, buf_tail};
  assign buf_head_next = (~queue_empty & advance_head) ? 
                            {buf_head_pol, buf_head} + 1 : {buf_head_pol, buf_head};

  // buf sequencing
  always @(posedge clk) begin
    if (bfs_rst) begin
      {buf_head_pol, buf_head} <= 0;
      {buf_tail_pol, buf_tail} <= 0;
    end else begin
      {buf_head_pol, buf_head} <= buf_head_next;
      {buf_tail_pol, buf_tail} <= buf_tail_next;
    end
  end


  wire wraparound = (buf_head_pol ^ buf_tail_pol);
  wire pt_eq = (buf_head === buf_tail);

  // Sim hack
  assign bt = buf_tail + 1;
  wire pt_full = (bt[$clog2(Q_SIZE)-1:0] === buf_head);

  assign queue_full = pt_full;
  assign queue_empty = ~buf_valid0[buf_head];
  
  assign rdata_out = {buf_addr1[buf_head], buf_addr0[buf_head]};
  assign rdata_filled = buf_valid01[buf_head];

  // Debugging
  assign tail_data = {buf_addr1[buf_tail], buf_addr0[buf_tail]};
endmodule 
