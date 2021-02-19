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
  output [31:6] l2_bus_addr,
  output [63:0] l2_bus_data,
  output        l2_bus_hit,
  output        l2_bus_nack,
  input         bus_l2_grant,

  input         bus_valid,
  input         bus_nack,
  input [2:0]   bus_cmd,
  input [4:0]   bus_tag,
  input [31:6]  bus_addr,
  input [63:0]  bus_data);

  /*AUTOWIRE*/
  // Beginning of automatic wires (for undeclared instantiated-module outputs)
  wire [31:6] l2data_req_addr;
  wire [2:0]  l2data_req_cmd;
  wire [63:0] l2data_req_data;
  wire        l2data_req_ready;
  wire        l2data_req_valid;
  wire [31:6] l2data_snoop_addr;
  wire [63:0] l2data_snoop_data;
  wire        l2data_snoop_ready;
  wire [4:0]  l2data_snoop_tag;
  wire        l2data_snoop_valid;
  wire [31:2] l2reqfifo_addr;
  wire        l2reqfifo_dcache;
  wire        l2reqfifo_valid;
  wire [31:0] l2reqfifo_wdata;
  wire        l2reqfifo_wen;
  wire [3:0]  l2reqfifo_wmask;
  wire        l2tag_l2reqfifo_ready;
  wire [31:3] l2tag_req_addr;
  wire [2:0]  l2tag_req_cmd;
  wire        l2tag_req_cmd_valid;
  wire        l2tag_req_dcache;
  wire        l2tag_req_valid;
  wire [3:0]  l2tag_req_way;
  wire [63:0] l2tag_req_wdata;
  wire        l2tag_req_wen;
  wire [7:0]  l2tag_req_wmask;
  wire [31:6] l2tag_snoop_addr;
  wire [4:0]  l2tag_snoop_tag;
  wire        l2tag_snoop_valid;
  wire [3:0]  l2tag_snoop_way;
  wire [63:0] l2tag_snoop_wdata;
  wire        l2tag_snoop_wen;
  wire        l2trans_l2data_req_ready;
  wire        l2trans_l2data_snoop_ready;
  wire [2:0]  l2trans_tag;
  wire        l2trans_valid;
  // End of automatics

  l2reqfifo l2reqfifo(
    /*AUTOINST*/
    // Outputs
    .l2_dc_ready      (l2_dc_ready),
    .l2_ic_ready      (l2_ic_ready),
    .l2reqfifo_addr   (l2reqfifo_addr[31:2]),
    .l2reqfifo_dcache (l2reqfifo_dcache),
    .l2reqfifo_valid  (l2reqfifo_valid),
    .l2reqfifo_wdata  (l2reqfifo_wdata[31:0]),
    .l2reqfifo_wen    (l2reqfifo_wen),
    .l2reqfifo_wmask  (l2reqfifo_wmask[3:0]),
    // Inputs
    .clk              (clk),
    .dcache_l2_addr   (dcache_l2_addr),
    .dcache_l2_req    (dcache_l2_req),
    .dcache_l2_wdata  (dcache_l2_wdata),
    .dcache_l2_wen    (dcache_l2_wen),
    .dcache_l2_wmask  (dcache_l2_wmask),
    .icache_addr      (icache_addr),
    .icache_req       (icache_req),
    .l2tag_l2reqfifo_ready(l2tag_l2reqfifo_ready),
    .rst              (rst));

  l2tag l2tag(
    /*AUTOINST*/
    // Outputs
    .l2_bus_hit       (l2_bus_hit),
    .l2_bus_nack      (l2_bus_nack),
    .l2_iaddr         (l2_iaddr),
    .l2_invalidate    (l2_invalidate),
    .l2tag_l2reqfifo_ready(l2tag_l2reqfifo_ready),
    .l2tag_req_addr   (l2tag_req_addr[31:3]),
    .l2tag_req_cmd    (l2tag_req_cmd[2:0]),
    .l2tag_req_cmd_valid(l2tag_req_cmd_valid),
    .l2tag_req_dcache (l2tag_req_dcache),
    .l2tag_req_valid  (l2tag_req_valid),
    .l2tag_req_way    (l2tag_req_way[3:0]),
    .l2tag_req_wdata  (l2tag_req_wdata[63:0]),
    .l2tag_req_wen    (l2tag_req_wen),
    .l2tag_req_wmask  (l2tag_req_wmask[7:0]),
    .l2tag_snoop_addr (l2tag_snoop_addr[31:6]),
    .l2tag_snoop_tag  (l2tag_snoop_tag[4:0]),
    .l2tag_snoop_valid(l2tag_snoop_valid),
    .l2tag_snoop_way  (l2tag_snoop_way[3:0]),
    .l2tag_snoop_wdata(l2tag_snoop_wdata[63:0]),
    .l2tag_snoop_wen  (l2tag_snoop_wen),
    // Inputs
    .bus_addr         (bus_addr),
    .bus_cmd          (bus_cmd),
    .bus_data         (bus_data),
    .bus_nack         (bus_nack),
    .bus_tag          (bus_tag),
    .bus_valid        (bus_valid),
    .clk              (clk),
    .l2data_req_ready (l2data_req_ready),
    .l2data_snoop_ready(l2data_snoop_ready),
    .l2reqfifo_addr   (l2reqfifo_addr[31:2]),
    .l2reqfifo_dcache (l2reqfifo_dcache),
    .l2reqfifo_valid  (l2reqfifo_valid),
    .l2reqfifo_wdata  (l2reqfifo_wdata[31:0]),
    .l2reqfifo_wen    (l2reqfifo_wen),
    .l2reqfifo_wmask  (l2reqfifo_wmask[3:0]),
    .l2trans_tag      (l2trans_tag[2:0]),
    .l2trans_valid    (l2trans_valid),
    .rst              (rst));

  l2data l2data(
    /*AUTOINST*/
    // Outputs
    .l2_dc_valid    (l2_dc_valid),
    .l2_error       (l2_error),
    .l2_ic_valid    (l2_ic_valid),
    .l2_rdata       (l2_rdata),
    .l2data_req_addr(l2data_req_addr[31:6]),
    .l2data_req_cmd (l2data_req_cmd[2:0]),
    .l2data_req_data(l2data_req_data[63:0]),
    .l2data_req_ready(l2data_req_ready),
    .l2data_req_valid(l2data_req_valid),
    .l2data_snoop_addr(l2data_snoop_addr[31:6]),
    .l2data_snoop_data(l2data_snoop_data[63:0]),
    .l2data_snoop_ready(l2data_snoop_ready),
    .l2data_snoop_tag(l2data_snoop_tag[4:0]),
    .l2data_snoop_valid(l2data_snoop_valid),
    // Inputs
    .clk            (clk),
    .dcache_l2_ready(dcache_l2_ready),
    .l2tag_req_addr (l2tag_req_addr[31:3]),
    .l2tag_req_cmd  (l2tag_req_cmd[2:0]),
    .l2tag_req_cmd_valid(l2tag_req_cmd_valid),
    .l2tag_req_dcache(l2tag_req_dcache),
    .l2tag_req_valid(l2tag_req_valid),
    .l2tag_req_way  (l2tag_req_way[3:0]),
    .l2tag_req_wdata(l2tag_req_wdata[63:0]),
    .l2tag_req_wen  (l2tag_req_wen),
    .l2tag_req_wmask(l2tag_req_wmask[7:0]),
    .l2tag_snoop_addr(l2tag_snoop_addr[31:6]),
    .l2tag_snoop_tag(l2tag_snoop_tag[4:0]),
    .l2tag_snoop_valid(l2tag_snoop_valid),
    .l2tag_snoop_way(l2tag_snoop_way[3:0]),
    .l2tag_snoop_wdata(l2tag_snoop_wdata[63:0]),
    .l2tag_snoop_wen(l2tag_snoop_wen),
    .l2trans_l2data_req_ready(l2trans_l2data_req_ready),
    .l2trans_l2data_snoop_ready(l2trans_l2data_snoop_ready),
    .rst            (rst));

  l2trans l2trans(
    /*AUTOINST*/
    // Outputs
    .l2_bus_addr          (l2_bus_addr),
    .l2_bus_cmd           (l2_bus_cmd),
    .l2_bus_data          (l2_bus_data),
    .l2_bus_req           (l2_bus_req),
    .l2_bus_tag           (l2_bus_tag),
    .l2trans_l2data_req_ready(l2trans_l2data_req_ready),
    .l2trans_l2data_snoop_ready(l2trans_l2data_snoop_ready),
    .l2trans_tag          (l2trans_tag[2:0]),
    .l2trans_valid        (l2trans_valid),
    // Inputs
    .bus_addr             (bus_addr),
    .bus_cmd              (bus_cmd),
    .bus_l2_grant         (bus_l2_grant),
    .bus_nack             (bus_nack),
    .bus_tag              (bus_tag),
    .bus_valid            (bus_valid),
    .clk                  (clk),
    .l2data_req_addr      (l2data_req_addr[31:6]),
    .l2data_req_cmd       (l2data_req_cmd[2:0]),
    .l2data_req_data      (l2data_req_data[63:0]),
    .l2data_req_valid     (l2data_req_valid),
    .l2data_snoop_addr    (l2data_snoop_addr[31:6]),
    .l2data_snoop_data    (l2data_snoop_data[63:0]),
    .l2data_snoop_tag     (l2data_snoop_tag[4:0]),
    .l2data_snoop_valid   (l2data_snoop_valid),
    .rst                  (rst));

endmodule
