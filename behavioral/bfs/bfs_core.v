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
  output [31:0]     bfs_dc_addr,
  input             dc_ready,
  input             dc_rbuf_empty,
  input             dc_valid,
  input [63:0]      dc_rdata);

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
    REG_QSIZE = 4'd4;

  // Queue interface
  reg q_rst;
  reg [1:0] enq_req;
  reg [63:0] enq_data;

  wire deq_req;
  assign deq_req = (~q_empty & dc_ready);// & (state !== IDLE) & (state !== INIT));

  wire [31:0] deq_data;
  wire q_full, q_empty;

  bfs_queue q (
    .clk (clk),
    .bfs_rst (q_rst),
    .enqueue_req (enq_req),
    .wdata_in (enq_data),
    .dequeue_req (deq_req),
    .rdata_out (deq_data),
    .queue_full (q_full),
    .queue_empty (q_empty));

  // Input Regs
  reg[31:0] from_node;
  reg[31:0] to_node;
  reg[31:0] sw_queue_base;
  reg[31:0] sw_queue_size;

  // Cache
  assign bfs_dc_req = deq_req;
  assign bfs_dc_addr = deq_data;

  reg[2:0] dc_beat;
  always @(posedge clk)
    if(rst)
      dc_beat <= 0;
    else if(dc_valid)
      dc_beat <= dc_beat + 1;

  wire dc_fs;
  assign dc_fs = dc_valid & (dc_beat == 0);

  // State Machine: Queue insertion
  reg found;
  reg[3:0] neigh_ct, next_neigh_ct;
  reg[1:0] state;
  reg[1:0] next_state;
  
  wire start;
  assign start = csr_bfs_valid & csr_bfs_wen & (csr_bfs_addr == REG_STAT);

  wire marked = dc_rdata[0];
  wire [3:0] rdata_neigh_ct = dc_rdata[32+:4];

  wire init_add_neighs; // If it has neighbors, unmarked, and frame start
  assign init_add_neighs = (|rdata_neigh_ct & ~marked & dc_fs);
  
  wire last_neigh_iter; // Either 1 or 2 neighs left
  assign last_neigh_iter = (~|neigh_ct[3:2] & ~(neigh_ct[1] & neigh_ct[0]));

  //assign found = ~q_empty & (deq_data == to_node);
  wire done;
  assign done = (q_empty & dc_rbuf_empty);

  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      found <= 0;
    end else begin
      // State latching
      state <= next_state;
      neigh_ct <= next_neigh_ct;
      if (~q_empty & (deq_data == to_node))
        found <= 1;
    end
  end 

  always @(*) begin
    casez(state)
      IDLE: begin
        q_rst = 0;
        enq_req = 2'b00;
        next_neigh_ct = 4'b0;
        next_state = (start ? INIT : IDLE);
      end
      INIT: begin
        // Queue init: Insert from_node
        q_rst = 1;
        enq_req = 2'b01;
        enq_data = {32'b0, from_node};
        // Next
        next_neigh_ct = 4'b0;
        next_state = NODE_HEADER;
      end
      NODE_HEADER: begin
        q_rst = 0;
        enq_req = 2'b00;
        // Next
        next_neigh_ct = rdata_neigh_ct;
        next_state = (done ? IDLE : (init_add_neighs ? ADD_NEIGHS : NODE_HEADER));
      end
      ADD_NEIGHS: begin
        q_rst = 0;
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
      REG_STAT: bfs_csr_rdata <= {30'b0,done,found};
      REG_ROOT: bfs_csr_rdata <= from_node;
      REG_TARG: bfs_csr_rdata <= to_node;
      REG_QBASE: bfs_csr_rdata <= sw_queue_base;
      REG_QSIZE: bfs_csr_rdata <= sw_queue_size;
      default: bfs_csr_error <= 1;
    endcase
  end

  always @(posedge clk)
    if(csr_bfs_valid & csr_bfs_wen)
      case(csr_bfs_addr)
        REG_ROOT: from_node <= csr_bfs_wdata;
        REG_TARG: to_node <= csr_bfs_wdata;
        REG_QBASE: sw_queue_base <= csr_bfs_wdata;
        REG_QSIZE: sw_queue_size <= csr_bfs_wdata;
      endcase

endmodule
