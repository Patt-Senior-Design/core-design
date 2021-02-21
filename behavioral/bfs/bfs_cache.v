module bfs_cache (
  input clk,
  input rst,

  // Sync for request
  input bfs_dc_req,
  input [31:0] bfs_dc_addr,
  output dc_ready,
  output dc_rbuf_empty,
  // Sync for result
  output dc_fs,
  output [63:0] dc_rdata);

  reg [63:0] storage [511:0]; // Store 8-Byte elements. 12-bit (4096) address space, byte-addressable
  integer i;

  initial begin
    for (i = 0; i < 4096; i=i+1) begin
      //storage[i/8][(i & 3'b111)*8 +: 8]  = (i & 8'hFF);
      if (i % 8)
        storage[i/8] += (i << 32);
      else
        storage[i/8] = (1 << 32);
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
      req <= bfs_dc_req;

      if (~ready | counter[0]) begin
        counter <= counter - 1;
        rdata <= storage[(addr_base >> 6) + 8 - counter]; // Get 8 bytes
        if (counter[3]) // Mark on first iteration
          storage[addr_base >> 6] <= storage[addr_base >> 6] | (63'h01);
      end

      if (bfs_dc_req) begin
        counter <= 8;
        addr_base <= bfs_dc_addr;
      end
    end
  end

  assign dc_rbuf_empty = ~req & (~|counter);
  assign dc_ready = ready;
  assign dc_fs = &counter[2:0];
  assign dc_rdata = rdata;


endmodule
