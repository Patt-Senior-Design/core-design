// l2 bus receiver
module l2recv(
  input         clk,
  input         rst,

  // l2 interface
  // l2->l2recv tagmem updates
  input         l2_l2recv_valid,
  input [31:6]  l2_l2recv_addr,
  input [3:0]   l2_l2recv_way,
  input [1:0]   l2_l2recv_state,
  input [2:0]   l2_l2recv_lru,
  // l2recv->l2 FILL/FLUSHOPT data, BUSRD/BUSRDX requests, BUSRDX/BUSUPGR invalidations
  output        l2recv_l2_fill,
  output        l2recv_l2_flush,
  output        l2recv_l2_invalidate,
  output [31:6] l2recv_l2_addr,
  output [3:0]  l2recv_l2_way,
  output [63:0] l2recv_l2_data,
  input         l2_l2recv_ready, // cannot be asserted indefinitely

  // bus interface
  output        l2_bus_hit,
  output        l2_bus_nack,

  input         bus_valid,
  input         bus_nack,
  input [2:0]   bus_cmd,
  input [4:0]   bus_tag,
  input [31:2]  bus_addr,
  input [63:0]  bus_data);

  function automatic [8:0] addr2set(
    input [31:2] addr);

    addr2set = addr[14:6];
  endfunction

  function automatic [16:0] addr2tag(
    input [31:2] addr);

    addr2tag = addr[31:15];
  endfunction

  // 2*4 state bits, 3 lru bits, 17*4 tag bits
  reg [7:0]  tagmem_state [0:511];
  reg [2:0]  tagmem_lru [0:511];
  reg [67:0] tagmem_tag [0:511];

  reg [2:0]  bus_cycle_r;

  // maps request tags to addrs
  // populated via snooping of our own requests
  reg [31:6] reqtags [0:7];

  // buffer for response data
  // size depends on how long l2 can deassert l2_l2recv_ready
  reg [63:0] respdata [0:15];

  // bus_cycle_r
  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_r + 1;

endmodule
