`include "buscmd.vh"

// l2 cache
module l2(
  input         clk,
  input         rst,

  // icache interface (in)
  input         icache_req,
  input [31:6]  icache_addr,
  output        l2_ic_ready,

  // dcache interface (in)
  input         dcache_l2_req,
  input [31:2]  dcache_l2_addr,
  input         dcache_l2_wen,
  input [3:0]   dcache_l2_wmask,
  input [31:0]  dcache_l2_wdata,
  output        l2_dc_ready,

  // icache/dcache interface (out)
  output        l2_ic_valid,
  output        l2_dc_valid,
  output        l2_error,
  output [63:0] l2_rdata,
  input         dcache_l2_ready,

  output        l2_invalidate,
  output [31:6] l2_iaddr,

  // bus interface
  output        l2_bus_req,
  output [2:0]  l2_bus_cmd,
  output [4:0]  l2_bus_tag,
  output [31:2] l2_bus_addr,
  output [63:0] l2_bus_data,
  output        l2_bus_hit,
  output        l2_bus_nack,
  input         bus_l2_grant,

  input         bus_valid,
  input         bus_nack,
  input [2:0]   bus_cmd,
  input [4:0]   bus_tag,
  input [31:2]  bus_addr,
  input [63:0]  bus_data);

  // 128KB, 4-way associative, 64B line => 512 sets
  function automatic [8:0] addr2set(
    input [31:2] addr);

    addr2set = addr[14:6];
  endfunction

  function automatic [16:0] addr2tag(
    input [31:2] addr);

    addr2tag = addr[31:15];
  endfunction

  // one-hot signal to index
  function automatic [1:0] oh2idx(
    input [3:0] onehot);

    begin
      oh2idx[1] = onehot[2] | onehot[3];
      oh2idx[0] = onehot[1] | onehot[3];
    end
  endfunction

  function [2:0] next_lru(
    input [3:0] way,
    input [2:0] lru);

    reg [1:0] way_idx;
    begin
      way_idx = oh2idx(way);
      next_lru[2] = ~way_idx[1];
      next_lru[1] = way_idx[1] ? ~way_idx[0] : lru[1];
      next_lru[0] = ~way_idx[1] ? ~way_idx[0] : lru[0];
    end
  endfunction

  // 2*4 state bits, 3 lru bits, 17*4 tag bits
  reg [7:0]   tagmem_state [0:511];
  reg [2:0]   tagmem_lru [0:511];
  reg [67:0]  tagmem_tag [0:511];

  // 4 banks, 8B wide, 32KB, 64B line => 4096 entries each
  reg [63:0]  datamem0 [0:4095];
  reg [63:0]  datamem1 [0:4095];
  reg [63:0]  datamem2 [0:4095];
  reg [63:0]  datamem3 [0:4095];

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [31:6] l2recv_l2_addr;
  wire [63:0] l2recv_l2_data;
  wire        l2recv_l2_fill;
  wire        l2recv_l2_flush;
  wire        l2recv_l2_invalidate;
  wire [3:0]  l2recv_l2_way;
  wire [31:2] l2reqfifo_addr;
  wire        l2reqfifo_dcache;
  wire        l2reqfifo_valid;
  wire [31:0] l2reqfifo_wdata;
  wire        l2reqfifo_wen;
  wire [3:0]  l2reqfifo_wmask;
  wire        l2trans_l2_ready;
  wire        l2trans_l2_valid;
  // End of automatics

  l2reqfifo reqfifo(
    /*AUTOINST*/
    // Outputs
    .l2_dc_ready        (l2_dc_ready),
    .l2_ic_ready        (l2_ic_ready),
    .l2reqfifo_addr     (l2reqfifo_addr[31:2]),
    .l2reqfifo_dcache   (l2reqfifo_dcache),
    .l2reqfifo_valid    (l2reqfifo_valid),
    .l2reqfifo_wdata    (l2reqfifo_wdata[31:0]),
    .l2reqfifo_wen      (l2reqfifo_wen),
    .l2reqfifo_wmask    (l2reqfifo_wmask[3:0]),
    // Inputs
    .clk                (clk),
    .dcache_l2_addr     (dcache_l2_addr),
    .dcache_l2_req      (dcache_l2_req),
    .dcache_l2_wdata    (dcache_l2_wdata),
    .dcache_l2_wen      (dcache_l2_wen),
    .dcache_l2_wmask    (dcache_l2_wmask),
    .icache_addr        (icache_addr),
    .icache_req         (icache_req),
    .l2_l2reqfifo_ready (l2_l2reqfifo_ready),
    .rst                (rst));

  l2recv recv(
    /*AUTOINST*/
    // Outputs
    .l2_bus_hit       (l2_bus_hit),
    .l2_bus_nack      (l2_bus_nack),
    .l2recv_l2_addr   (l2recv_l2_addr[31:6]),
    .l2recv_l2_data   (l2recv_l2_data[63:0]),
    .l2recv_l2_fill   (l2recv_l2_fill),
    .l2recv_l2_flush  (l2recv_l2_flush),
    .l2recv_l2_invalidate(l2recv_l2_invalidate),
    .l2recv_l2_way    (l2recv_l2_way[3:0]),
    // Inputs
    .bus_addr         (bus_addr),
    .bus_cmd          (bus_cmd),
    .bus_data         (bus_data),
    .bus_nack         (bus_nack),
    .bus_tag          (bus_tag),
    .bus_valid        (bus_valid),
    .clk              (clk),
    .l2_l2recv_addr   (l2_l2recv_addr[31:6]),
    .l2_l2recv_lru    (l2_l2recv_lru[2:0]),
    .l2_l2recv_ready  (l2_l2recv_ready),
    .l2_l2recv_state  (l2_l2recv_state[1:0]),
    .l2_l2recv_valid  (l2_l2recv_valid),
    .l2_l2recv_way    (l2_l2recv_way[3:0]),
    .rst              (rst));

  l2trans trans(
    /*AUTOINST*/
    // Outputs
    .l2_bus_addr    (l2_bus_addr),
    .l2_bus_cmd     (l2_bus_cmd),
    .l2_bus_data    (l2_bus_data),
    .l2_bus_req     (l2_bus_req),
    .l2_bus_tag     (l2_bus_tag),
    .l2trans_l2_ready(l2trans_l2_ready),
    .l2trans_l2_valid(l2trans_l2_valid),
    // Inputs
    .bus_addr       (bus_addr),
    .bus_cmd        (bus_cmd),
    .bus_l2_grant   (bus_l2_grant),
    .bus_nack       (bus_nack),
    .bus_tag        (bus_tag),
    .bus_valid      (bus_valid),
    .clk            (clk),
    .l2_l2trans_addr(l2_l2trans_addr[31:6]),
    .l2_l2trans_cmd (l2_l2trans_cmd[2:0]),
    .l2_l2trans_data(l2_l2trans_data[63:0]),
    .l2_l2trans_valid(l2_l2trans_valid),
    .rst            (rst));

endmodule
