module bfs_cache (
  input clk,
  input rst,

  // Sync for request
  input bfs_req,
  input [31:0] bfs_req_addr,
  output cache_ready,

  // Sync for result
  output cache_fs,
  output [63:0] cache_rdata);

  reg [63:0] storage [511:0]; // Store 8-Byte elements. 12-bit (4096) address space, byte-addressable
  integer i;

  initial begin
    for (i = 0; i < 4096; i=i+1) begin
      //storage[i/8][(i & 3'b111)*8 +: 8]  = (i & 8'hFF);
      if (i % 8)
        storage[i/8] += i;
      else
        storage[i/8] = 0;
    end
  end


  wire ready;
  assign ready = ~|counter[3:1];

  reg req;
  reg [31:0] addr_base;
  reg [3:0] counter;
  reg [63:0] rdata;

  always @(posedge clk) begin
    if (rst) begin
      req <= 0;
      counter <= 0;
    end else begin
      req <= bfs_req;

      if (~ready | counter[0]) begin
        counter <= counter - 1;
        rdata <= storage[(addr_base >> 6) + 8 - counter]; // Get 8 bytes
        if (counter[3]) // Mark on first iteration
          storage[addr_base >> 6] <= storage[addr_base >> 6] | (1 << 32);
      end

      if (bfs_req) begin
        counter <= 8;
        addr_base <= bfs_req_addr;
      end
    end
  end


  assign cache_ready = ready;
  assign cache_fs = &counter[2:0];
  assign cache_rdata = rdata;


endmodule
