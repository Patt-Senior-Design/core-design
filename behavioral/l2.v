`include "buscmd.vh"

// l2 cache
module l2(
  input         clk,
  input         rst,

  // request interface
  input         req_valid,
  input [1:0]   req_op,
  input [31:2]  req_addr,
  input [3:0]   req_wmask,
  input [31:0]  req_wdata,
  output        l2_req_ready,

  // response interface
  output        l2_resp_valid,
  output        l2_resp_error,
  output [63:0] l2_resp_rdata,
  input         resp_ready,

  output        l2_inv_valid,
  output [31:6] l2_inv_addr,
  input         inv_ready,

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
  wire        l2data_flush_hit;
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
  wire [31:6] l2tag_inv_addr;
  wire        l2tag_inv_valid;
  wire [31:3] l2tag_req_addr;
  wire [2:0]  l2tag_req_cmd;
  wire        l2tag_req_cmd_valid;
  wire [1:0]  l2tag_req_op;
  wire        l2tag_req_valid;
  wire [3:0]  l2tag_req_way;
  wire [63:0] l2tag_req_wdata;
  wire [7:0]  l2tag_req_wmask;
  wire [31:6] l2tag_snoop_addr;
  wire [4:0]  l2tag_snoop_tag;
  wire        l2tag_snoop_valid;
  wire [3:0]  l2tag_snoop_way;
  wire [63:0] l2tag_snoop_wdata;
  wire        l2tag_snoop_wen;
  wire        l2trans_flush_hit;
  wire        l2trans_l2data_req_ready;
  wire        l2trans_l2data_snoop_ready;
  wire [2:0]  l2trans_tag;
  wire        l2trans_valid;
  // End of automatics

  l2tag l2tag(
    /*AUTOINST*/
    // Outputs
    .l2_bus_hit       (l2_bus_hit),
    .l2_bus_nack      (l2_bus_nack),
    .l2_req_ready     (l2_req_ready),
    .l2tag_inv_addr   (l2tag_inv_addr[31:6]),
    .l2tag_inv_valid  (l2tag_inv_valid),
    .l2tag_req_addr   (l2tag_req_addr[31:3]),
    .l2tag_req_cmd    (l2tag_req_cmd[2:0]),
    .l2tag_req_cmd_valid(l2tag_req_cmd_valid),
    .l2tag_req_op     (l2tag_req_op[1:0]),
    .l2tag_req_valid  (l2tag_req_valid),
    .l2tag_req_way    (l2tag_req_way[3:0]),
    .l2tag_req_wdata  (l2tag_req_wdata[63:0]),
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
    .invfifo_ready    (invfifo_ready),
    .l2data_flush_hit (l2data_flush_hit),
    .l2data_req_ready (l2data_req_ready),
    .l2data_snoop_ready(l2data_snoop_ready),
    .l2trans_flush_hit(l2trans_flush_hit),
    .l2trans_tag      (l2trans_tag[2:0]),
    .l2trans_valid    (l2trans_valid),
    .req_addr         (req_addr),
    .req_op           (req_op),
    .req_valid        (req_valid),
    .req_wdata        (req_wdata),
    .req_wmask        (req_wmask),
    .rst              (rst));

  l2data l2data(
    /*AUTOINST*/
    // Outputs
    .l2_resp_error  (l2_resp_error),
    .l2_resp_rdata  (l2_resp_rdata),
    .l2_resp_valid  (l2_resp_valid),
    .l2data_flush_hit(l2data_flush_hit),
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
    .l2tag_inv_addr (l2tag_inv_addr[31:6]),
    .l2tag_inv_valid(l2tag_inv_valid),
    .l2tag_req_addr (l2tag_req_addr[31:3]),
    .l2tag_req_cmd  (l2tag_req_cmd[2:0]),
    .l2tag_req_cmd_valid(l2tag_req_cmd_valid),
    .l2tag_req_op   (l2tag_req_op[1:0]),
    .l2tag_req_valid(l2tag_req_valid),
    .l2tag_req_way  (l2tag_req_way[3:0]),
    .l2tag_req_wdata(l2tag_req_wdata[63:0]),
    .l2tag_req_wmask(l2tag_req_wmask[7:0]),
    .l2tag_snoop_addr(l2tag_snoop_addr[31:6]),
    .l2tag_snoop_tag(l2tag_snoop_tag[4:0]),
    .l2tag_snoop_valid(l2tag_snoop_valid),
    .l2tag_snoop_way(l2tag_snoop_way[3:0]),
    .l2tag_snoop_wdata(l2tag_snoop_wdata[63:0]),
    .l2tag_snoop_wen(l2tag_snoop_wen),
    .l2trans_l2data_req_ready(l2trans_l2data_req_ready),
    .l2trans_l2data_snoop_ready(l2trans_l2data_snoop_ready),
    .resp_ready     (resp_ready),
    .rst            (rst));

  l2trans l2trans(
    /*AUTOINST*/
    // Outputs
    .l2_bus_addr          (l2_bus_addr),
    .l2_bus_cmd           (l2_bus_cmd),
    .l2_bus_data          (l2_bus_data),
    .l2_bus_req           (l2_bus_req),
    .l2_bus_tag           (l2_bus_tag),
    .l2trans_flush_hit    (l2trans_flush_hit),
    .l2trans_l2data_req_ready(l2trans_l2data_req_ready),
    .l2trans_l2data_snoop_ready(l2trans_l2data_snoop_ready),
    .l2trans_tag          (l2trans_tag[2:0]),
    .l2trans_valid        (l2trans_valid),
    // Inputs
    .bus_l2_grant         (bus_l2_grant),
    .bus_nack             (bus_nack),
    .clk                  (clk),
    .l2data_req_addr      (l2data_req_addr[31:6]),
    .l2data_req_cmd       (l2data_req_cmd[2:0]),
    .l2data_req_data      (l2data_req_data[63:0]),
    .l2data_req_valid     (l2data_req_valid),
    .l2data_snoop_addr    (l2data_snoop_addr[31:6]),
    .l2data_snoop_data    (l2data_snoop_data[63:0]),
    .l2data_snoop_tag     (l2data_snoop_tag[4:0]),
    .l2data_snoop_valid   (l2data_snoop_valid),
    .l2tag_inv_addr       (l2tag_inv_addr[31:6]),
    .l2tag_inv_valid      (l2tag_inv_valid),
    .rst                  (rst));

  fifo #(26,8) invfifo(
    .clk(clk),
    .rst(rst),
    .wr_valid(l2tag_inv_valid),
    .wr_ready(invfifo_ready),
    .wr_data(l2tag_inv_addr),
    .rd_valid(l2_inv_valid),
    .rd_ready(inv_ready),
    .rd_data(l2_inv_addr));

endmodule
