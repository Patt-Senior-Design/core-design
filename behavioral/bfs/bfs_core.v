
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
  output [31:0] bfs_dc_addr,
  input         dc_ready,
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
  reg [5:0] rd;
  reg [6:0] robid;
  // TODO: Eventually make these CSRs
  reg[31:0] sw_queue_base;
  // Inputs from custom instruction
  reg[31:0] from_node;
  reg[31:0] to_node;

  // Input Reg Latching
  always @(posedge clk) begin
    if (rename_bfs_write & ~bfs_stall) begin
      rd <= rename_rd;
      robid <= rename_robid;
      from_node <= rename_op1;
      to_node <= rename_op2;
    end
  end


  // Cache 
  assign bfs_dc_req = deq_req;
  assign bfs_dc_addr = deq_data;


  // State Machine: Queue insertion
  reg found;
  reg[3:0] neigh_ct, next_neigh_ct;
  reg[1:0] state;
  reg[1:0] next_state;
  
  wire init_add_neighs; // If it has neighbors, unmarked, and frame start
  assign init_add_neighs = (|dc_rdata[32+:4] & ~dc_rdata[0] & dc_fs);
  
  wire last_neigh_iter; // Either 1 or 2 neighs left
  assign last_neigh_iter = (~|neigh_ct[3:2] & ~(neigh_ct[1] & neigh_ct[0]));

  //assign found = ~q_empty & (deq_data == to_node);
  wire done;
  assign done = (q_empty & dc_rbuf_empty) & (state == NODE_HEADER);

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      state <= IDLE;
      found <= 0;
      sw_queue_base <= 32'hF0000000;
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
        next_state = (rename_bfs_write ? INIT : IDLE);
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
        next_neigh_ct = dc_rdata[32+:4];
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


  assign bfs_stall = (state !== IDLE);
  assign bfs_valid = done;
  assign bfs_result = {31'b0, found};

  assign bfs_error = 0;
  assign bfs_ecause = 0;
  assign bfs_rd = rd;
  assign bfs_robid = robid;

endmodule
