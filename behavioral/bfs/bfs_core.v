`define SW_QUEUE_BASE 32'h00010000  // Node 
module bfs_core (
  input         clk,
  input         rst,

  // rename interface
  input         rename_bfs_write,
  input [6:0]   rename_robid,
  input [5:0]   rename_rd,
  input [31:0]  rename_op1,
  input [31:0]  rename_op2,
  output        bfs_stall,

  // writeback interface
  output        bfs_valid,
  output        bfs_error,
  output [4:0]  bfs_ecause,
  output [6:0]  bfs_robid,
  output [5:0]  bfs_rd,
  output [31:0] bfs_result,
  input         wb_bfs_stall,
  
  // cache interface
  output        bfs_dc_req,
  output reg [1:0]  bfs_dc_op,
  output reg [31:0] bfs_dc_addr,
  output [63:0] bfs_dc_wdata,
  input         dc_ready,
  input  [1:0]  dc_op,
  input         dc_rbuf_empty,
  input         dc_fs,
  input  [63:0] dc_rdata,

  // rob interface
  input         rob_flush);

  localparam
    IDLE = 2'b00,
    INIT = 2'b01,
    NODE_HEADER = 2'b10,
    ADD_NEIGHS = 2'b11;

  // Indication that bfs processing is active
  wire active;
  assign active = (state == NODE_HEADER | state == ADD_NEIGHS);

  // Queue interface
  wire q_rst;
  reg [1:0] enq_req;
  reg [63:0] enq_data;
  wire deq_req;
  wire [31:0] deq_data;
  wire q_full, rq_empty;
  wire pend_empty;
  wire spill_req;
  wire spill_op;
  wire [63:0] spill_data;

  assign q_rst = rst | rob_flush | done;
  assign deq_req = (~rq_empty & dc_ready & ~spill_req);

  bfs_queue #(.MAINQ_SIZE(16), .BUFQ_SIZE(16)) q (
    .clk (clk),
    .bfs_rst (q_rst),
    .active (active),
    .enqueue_req (enq_req),
    .wdata_in (enq_data),
    .dequeue_req (deq_req),
    .rdata_out (deq_data),
    .queue_full (q_full),
    .rqueue_empty (rq_empty),
    .pend_empty (pend_empty),
    .spill_req (spill_req),
    .spill_op (spill_op),
    .spill_data (spill_data),
    .dc_fs (dc_fs),
    .dc_op (dc_op),
    .dc_ready (dc_ready),
    .dc_rdata (dc_rdata),
    .dc_rbuf_empty (dc_rbuf_empty));

  // Input Regs
  reg [5:0] rd;
  reg [6:0] robid;
  // TODO: Eventually read them from CSRs
  reg[31:0] swq_tail;
  reg[31:0] swq_head;
  reg[31:0] from_node;
  reg[31:0] to_node;

  // Input Reg Latching
  always @(posedge clk) begin
    if (rename_bfs_write & ~bfs_stall) begin
      rd <= rename_rd;
      robid <= rename_robid;
      from_node <= rename_op1;
      to_node <= rename_op2;
      swq_tail <= `SW_QUEUE_BASE;
      swq_head <= `SW_QUEUE_BASE;
    end 
    if (spill_req) begin
      if (spill_op)
        swq_head <= swq_head + 64;
      else
        swq_tail <= swq_tail + 64;
    end
  end

  // State Machine: Queue insertion
  reg found;
  reg[3:0] neigh_ct, next_neigh_ct;
  reg[1:0] state;
  reg[1:0] next_state;
  
  wire marked = dc_rdata[63];
  wire [3:0] rdata_neigh_ct = dc_rdata[32+:4];

  wire init_add_neighs; // If it has neighbors, unmarked, and frame start
  assign init_add_neighs = (|rdata_neigh_ct & ~marked & dc_fs & (dc_op == 2'b00));
  
  wire last_neigh_iter; // Either 1 or 2 neighs left
  assign last_neigh_iter = (~|neigh_ct[3:2] & ~(neigh_ct[1] & neigh_ct[0]));

  wire done;
  assign done = (pend_empty & (swq_head === swq_tail));

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      state <= IDLE;
      found <= 0;
    end else begin
      // State latching
      state <= next_state;
      neigh_ct <= next_neigh_ct;
      if (~rq_empty & (deq_data == to_node))
        found <= 1;
      if (state == INIT)
        found <= 0;
    end
  end 

  always @(*) begin
    casez(state)
      IDLE: begin
        enq_req = 2'b00;
        next_neigh_ct = 4'b0;
        next_state = (rename_bfs_write ? INIT : IDLE);
      end
      INIT: begin
        // Queue init: Insert from_node
        enq_req = 2'b01;
        enq_data = {32'b0, from_node};
        // Next
        next_neigh_ct = 4'b0;
        next_state = NODE_HEADER;
      end
      NODE_HEADER: begin
        enq_req = 2'b00;
        // Next
        next_neigh_ct = rdata_neigh_ct;
        next_state = (done ? IDLE : (init_add_neighs ? ADD_NEIGHS : NODE_HEADER));
      end
      ADD_NEIGHS: begin
        enq_req = {|neigh_ct[3:1], 1'b1};
        enq_data = dc_rdata;
        // Next
        next_neigh_ct[3:1] = neigh_ct[3:1] - 1;
        next_state = (last_neigh_iter ? NODE_HEADER : ADD_NEIGHS);
      end
    endcase
  end

  // Cache
  assign bfs_dc_req = deq_req | spill_req;
  assign bfs_dc_wdata = spill_data;
  // Address 
  always @(*) begin
    casez({spill_req, spill_op})
      2'b0?: bfs_dc_addr = deq_data;
      2'b10: bfs_dc_addr = swq_tail;
      2'b11: bfs_dc_addr = swq_head;
    endcase
    bfs_dc_op = {spill_req & ~spill_op, spill_req};
  end

  assign bfs_stall = (state !== IDLE);
  assign bfs_valid = done;
  assign bfs_result = {31'b0, found};

  assign bfs_error = 0;
  assign bfs_ecause = 0;
  assign bfs_rd = rd;
  assign bfs_robid = robid;

endmodule
