`include "buscmd.vh"

module bfs_core (
  input             clk,
  input             rst,

  // csr interface
  input             csr_bfs_valid,
  input [3:0]       csr_bfs_addr,
  input             csr_bfs_wen,
  input [31:0]      csr_bfs_wdata,
  output reg        bfs_csr_valid,
  output reg        bfs_csr_error,
  output reg [31:0] bfs_csr_rdata,

  // cache interface
  output            bfs_dc_req,
  output reg [1:0]  bfs_dc_op,
  output reg [31:0] bfs_dc_addr,
  output [63:0]     bfs_dc_wdata,
  input             dc_ready,

  input             dc_valid,
  input [1:0]       dc_op,
  input [31:6]      dc_addr,
  input [63:0]      dc_rdata,

  input             dc_rbuf_empty);

  localparam
    IDLE = 2'b00,
    INIT = 2'b01,
    NODE_HEADER = 2'b10,
    ADD_NEIGHS = 2'b11;

  localparam
    REG_STAT  = 4'd0,
    REG_ROOT  = 4'd1,
    REG_TARG  = 4'd2,
    REG_QBASE = 4'd3,
    REG_QSIZE = 4'd4,
    REG_RESULT = 4'd5;

  reg[2:0] dc_beat;
  always @(posedge clk)
    if(rst)
      dc_beat <= 0;
    else if(dc_valid)
      dc_beat <= dc_beat + 1;

  wire dc_fs;
  assign dc_fs = dc_valid & (dc_beat == 0);

  // Indication that bfs processing is active
  wire active;

  // Queue interface
  wire done;
  wire q_rst;
  reg [1:0] enq_req;
  reg [63:0] enq_data;

  wire deq_req;
  wire [31:0] deq_data;
  wire q_full, rq_empty;
  wire pend_empty;
  wire spill_req;
  wire spill_init;
  wire spill_op;
  wire [63:0] spill_data;

  assign q_rst = rst | done;
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
    .spill_done (spill_done),
    .spill_op (spill_op),
    .spill_data (spill_data),
    .dc_valid (dc_valid),
    .dc_op (dc_op),
    .dc_ready (dc_ready),
    .dc_rdata (dc_rdata),
    .dc_rbuf_empty (dc_rbuf_empty));

  // Input Regs
  reg[31:0] from_node;
  reg[31:0] target_val;
  reg[31:0] sw_queue_base;
  reg[31:0] sw_queue_size;
  reg[31:0] result;

  wire start;
  assign start = csr_bfs_valid & csr_bfs_wen & (csr_bfs_addr == REG_STAT);

  reg[31:0] swq_tail;
  reg[31:0] swq_head;
  always @(posedge clk)
    if (q_rst | start) begin
      swq_head <= sw_queue_base;
      swq_tail <= sw_queue_base;
    end else if (spill_done) begin
      if (spill_op)
        swq_head <= swq_head + 64;
      else
        swq_tail <= swq_tail + 64;
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

    if (spill_req)
      bfs_dc_op = spill_op ? `OP_RD : `OP_WR64;
    else
      bfs_dc_op = `OP_MARK;
  end

  // State Machine: Queue insertion
  reg found;
  reg[3:0] neigh_ct, next_neigh_ct;
  reg[1:0] state;
  reg[1:0] next_state;
  
  assign active = (state == NODE_HEADER | state == ADD_NEIGHS);

  wire [31:0] rdata_value = dc_rdata[31:0];
  wire [3:0]  rdata_neigh_ct = dc_rdata[32+:4];
  wire        rdata_marked = dc_rdata[32+24];

  wire rdata_valid;
  assign rdata_valid = dc_fs & (dc_op == `OP_MARK) & ~rdata_marked;

  wire init_add_neighs; // If it has neighbors, unmarked, and frame start
  assign init_add_neighs = rdata_valid & (|rdata_neigh_ct);
  
  wire last_neigh_iter; // Either 1 or 2 neighs left
  assign last_neigh_iter = (~|neigh_ct[3:2] & ~(neigh_ct[1] & neigh_ct[0]));

  wire rdata_hit;
  assign rdata_hit = rdata_valid & (rdata_value == target_val);
  assign done = rdata_hit | (pend_empty & (swq_head === swq_tail));

  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      found <= 0;
    end else begin
      // State latching
      state <= next_state;
      neigh_ct <= next_neigh_ct;
      if (rdata_hit) begin
        state <= IDLE;
        found <= 1;
        result <= {dc_addr,6'b0};
      end else if (state == INIT)
        found <= 0;
    end
  end 

  always @(*) begin
    casez(state)
      IDLE: begin
        enq_req = 2'b00;
        next_neigh_ct = 4'b0;
        next_state = (start ? INIT : IDLE);
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

  // CSR interface
  always @(posedge clk) begin
    bfs_csr_valid <= csr_bfs_valid;
    bfs_csr_error <= 0;
    case(csr_bfs_addr)
      REG_STAT: bfs_csr_rdata <= {30'b0,~active,found};
      REG_ROOT: bfs_csr_rdata <= from_node;
      REG_TARG: bfs_csr_rdata <= target_val;
      REG_QBASE: bfs_csr_rdata <= sw_queue_base;
      REG_QSIZE: bfs_csr_rdata <= sw_queue_size;
      REG_RESULT: bfs_csr_rdata <= result;
      default: bfs_csr_error <= 1;
    endcase
  end

  always @(posedge clk)
    if(csr_bfs_valid & csr_bfs_wen)
      case(csr_bfs_addr)
        REG_ROOT: from_node <= csr_bfs_wdata;
        REG_TARG: target_val <= csr_bfs_wdata;
        REG_QBASE: sw_queue_base <= csr_bfs_wdata;
        REG_QSIZE: sw_queue_size <= csr_bfs_wdata;
        REG_RESULT: result <= csr_bfs_wdata;
      endcase

endmodule
