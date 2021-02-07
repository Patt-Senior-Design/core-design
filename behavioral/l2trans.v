// l2 bus transmitter
module l2trans(
  input         clk,
  input         rst,

  // l2 interface
  // l2->l2trans commands
  input         l2_l2trans_valid,
  input [2:0]   l2_l2trans_cmd,
  input [31:6]  l2_l2trans_addr,
  input [63:0]  l2_l2trans_data,
  output        l2trans_l2_ready,

  // l2trans->l2 acknowledges
  output        l2trans_l2_valid,

  // bus interface
  output        l2_bus_req,
  output [2:0]  l2_bus_cmd,
  output [4:0]  l2_bus_tag,
  output [31:2] l2_bus_addr,
  output [63:0] l2_bus_data,
  input         bus_l2_grant,

  // we have to examine the current cmd as well
  input         bus_valid,
  input         bus_nack,
  input [2:0]   bus_cmd,
  input [4:0]   bus_tag,
  input [31:2]  bus_addr);

  reg [2:0]  bus_cycle_r;

  // buffer for current command
  reg        cmd_valid_r;
  reg [2:0]  cmd_r;
  reg [31:6] cmd_addr_r;
  reg [63:0] cmd_data [0:7];

endmodule
