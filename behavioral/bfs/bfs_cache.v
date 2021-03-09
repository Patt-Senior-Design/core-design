module bfs_cache (
  input clk,
  input rst,

  // Sync for request
  input bfs_dc_req,
  input [1:0] bfs_dc_op,
  input [31:0] bfs_dc_addr,
  output dc_ready,
  output dc_rbuf_empty,
  // Sync for result
  input [63:0] bfs_dc_wdata,
  output dc_fs,
  output [1:0] dc_op,
  output [63:0] dc_rdata);

  localparam 
    ADDR_BITS = 17,
    LOAD_MARK = 2'b00,
    LOAD_SPILL = 2'b01,
    STORE_SPILL = 2'b11;

  reg [31:0] storage [0:(1<<(ADDR_BITS-2))-1]; // Address Space 17-bit (15+2), 2^11 nodes
  integer i, fd;

  initial begin
    fd = $fopen("graph.mem", "r");
    if (!fd) begin
      $display("Cannot open graph.mem file");
      $finish;
    end
    $fclose(fd);
    $readmemh("graph.mem", storage);
    $display("Loaded graph storage");
  end


  wire ready;
  assign ready = ~|counter[3:1];

  wire[30:0] acc_addr;
  assign acc_addr = (addr_base >> 2) + (8 - counter)*2;

  // DEBUGGING
  wire [32:0] node = bfs_dc_addr >> 6;
  reg [30:0] deq_ct;
  always @(posedge clk) begin
    if (rst) deq_ct <= 0;
    else if (bfs_dc_req & (bfs_dc_op == LOAD_MARK)) deq_ct <= deq_ct + 1;
  end

  reg req;
  reg [1:0] op;
  reg [31:0] addr_base;
  reg [3:0] counter;
  reg [63:0] rdata;
  reg transfer;

  always @(negedge rst)
    $readmemh("graph.mem", storage);

  always @(posedge clk) begin
    if (rst) begin
      req <= 0;
      counter <= 0;
    end else begin
      req <= bfs_dc_req;

      if (~ready | counter[0]) begin
        counter <= counter - 1;
        rdata <= {storage[acc_addr + 1], storage[acc_addr]}; // Get 8 bytes
        casez(op)
          LOAD_MARK: begin
            if (counter[3]) // Mark on first iteration
              storage[acc_addr + 1] <= storage[acc_addr + 1] | (1 << 31);
          end
          STORE_SPILL: begin
            {storage[acc_addr + 1], storage[acc_addr]} <= bfs_dc_wdata;
          end
        endcase
      end

      if (bfs_dc_req) begin
        counter <= 8;
        addr_base <= bfs_dc_addr;
        op <= bfs_dc_op;
      end
      
    end
    transfer <= |counter;
  end

  assign dc_rbuf_empty = ~req & ~transfer;
  assign dc_ready = ready;
  assign dc_fs = &counter[2:0];
  assign dc_op = op;
  assign dc_rdata = rdata;


endmodule
