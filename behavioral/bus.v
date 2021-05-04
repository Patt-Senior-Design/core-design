`include "buscmd.vh"

// main bus
module bus(
  input             clk,
  input             rst,

  // l2 interface
  input             l2_bus_req,
  input [2:0]       l2_bus_cmd,
  input [4:0]       l2_bus_tag,
  input [31:6]      l2_bus_addr,
  input [63:0]      l2_bus_data,
  input             l2_bus_hit,
  input             l2_bus_nack,
  output reg        bus_l2_grant,

  // bfs interface
  input             bfs_bus_req,
  input [2:0]       bfs_bus_cmd,
  input [4:0]       bfs_bus_tag,
  input [31:6]      bfs_bus_addr,
  input [63:0]      bfs_bus_data,
  input             bfs_bus_hit,
  input             bfs_bus_nack,
  output reg        bus_bfs_grant,

  // dramctl interface
  input             dramctl_bus_req,
  input [2:0]       dramctl_bus_cmd,
  input [4:0]       dramctl_bus_tag,
  input [31:6]      dramctl_bus_addr,
  input [63:0]      dramctl_bus_data,
  input             dramctl_bus_nack,
  output reg        bus_dramctl_grant,

  // rom interface
  input             rom_bus_req,
  input [2:0]       rom_bus_cmd,
  input [4:0]       rom_bus_tag,
  input [31:6]      rom_bus_addr,
  input [63:0]      rom_bus_data,
  input             rom_bus_nack,
  output reg        bus_rom_grant,

  // common outputs
  output reg        bus_valid,
  output reg        bus_nack,
  output reg        bus_hit,
  output reg [2:0]  bus_cmd,
  output reg [4:0]  bus_tag,
  output reg [31:6] bus_addr,
  output reg [63:0] bus_data);

  // positive amount = left shift
  function integer rotate(
    input integer in,
    input integer amount,
    input integer width);

    if(amount > 0)
      rotate = (in << amount) | (in >> (width - amount));
    else
      rotate = (in << (width - (-amount))) | (in >> -amount);
  endfunction

  reg [2:0] bus_cycle_r;
  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_r + 1;

  // request arbitration (round-robin)
  // responses have precedence over requests
  wire       l2_req, l2_resp;
  wire       bfs_req, bfs_resp;
  wire [1:0] reqs;
  wire [3:0] resps;
  assign l2_req = l2_bus_req & ~l2_bus_cmd[2];
  assign l2_resp = l2_bus_req & l2_bus_cmd[2];
  assign bfs_req = bfs_bus_req & ~bfs_bus_cmd[2];
  assign bfs_resp = bfs_bus_req & bfs_bus_cmd[2];
  assign reqs = {bfs_req,l2_req};
  assign resps = {rom_bus_req,dramctl_bus_req,bfs_resp,l2_resp};

  reg       req_pri_r;
  reg [1:0] resp_pri_r;

  /*verilator lint_off WIDTH*/
  wire [1:0] reqs_rot;
  wire [3:0] resps_rot;
  assign reqs_rot = rotate(reqs, req_pri_r, 2);
  assign resps_rot = rotate(resps, resp_pri_r, 4);
  /*verilator lint_on WIDTH*/

  wire       reqarb_valid, resparb_valid;
  wire [1:0] reqarb_out;
  wire [3:0] resparb_out;
  priarb #(2) reqarb(
    .req(reqs_rot),
    .grant_valid(reqarb_valid),
    .grant(reqarb_out));
  priarb #(4) resparb(
    .req(resps_rot),
    .grant_valid(resparb_valid),
    .grant(resparb_out));

  /*verilator lint_off WIDTH*/
  wire [1:0] reqarb_rot;
  wire [3:0] resparb_rot;
  assign reqarb_rot = rotate(reqarb_out, -req_pri_r, 2);
  assign resparb_rot = rotate(resparb_out, -resp_pri_r, 4);
  /*verilator lint_on WIDTH*/

  reg [3:0] arb_out;
  always @(*) begin
    if(resparb_valid)
      arb_out = resparb_rot;
    else if(reqarb_valid)
      arb_out = {2'b00,reqarb_rot};
    else
      arb_out = 4'b0000;

    {bus_rom_grant,bus_dramctl_grant,bus_bfs_grant,bus_l2_grant} = arb_out;
  end

  always @(posedge clk)
    if(rst) begin
      req_pri_r <= 0;
      resp_pri_r <= 0;
    end else if(bus_cycle_r == 7)
      if(resparb_valid)
        resp_pri_r <= resp_pri_r + 1;
      else if(reqarb_valid)
        req_pri_r <= req_pri_r + 1;

  reg l2_grant_r, bfs_grant_r, dramctl_grant_r, rom_grant_r;
  always @(posedge clk)
    if(rst) begin
      l2_grant_r <= 0;
      bfs_grant_r <= 0;
      dramctl_grant_r <= 0;
      rom_grant_r <= 0;
    end else if(bus_cycle_r == 7) begin
      l2_grant_r <= bus_l2_grant;
      bfs_grant_r <= bus_bfs_grant;
      dramctl_grant_r <= bus_dramctl_grant;
      rom_grant_r <= bus_rom_grant;
    end

  // output muxes
  always @(*) begin
    bus_valid = l2_grant_r | bfs_grant_r | dramctl_grant_r | rom_grant_r;
    // asserted during request by cache to inhibit dramctl response (cache-to-cache transfer)
    bus_hit = l2_bus_hit | bfs_bus_hit;
    // asserted during request to indicate that it should be tried again later
    bus_nack = l2_bus_nack | bfs_bus_nack | dramctl_bus_nack | rom_bus_nack;

    bus_cmd = 0;
    bus_tag = 0;
    bus_addr = 0;
    bus_data = 0;
    if(l2_grant_r) begin
      bus_cmd = bus_cmd | l2_bus_cmd;
      bus_tag = bus_tag | l2_bus_tag;
      bus_addr = bus_addr | l2_bus_addr;
      bus_data = bus_data | l2_bus_data;
    end
    if(bfs_grant_r) begin
      bus_cmd = bus_cmd | bfs_bus_cmd;
      bus_tag = bus_tag | bfs_bus_tag;
      bus_addr = bus_addr | bfs_bus_addr;
      bus_data = bus_data | bfs_bus_data;
    end
    if(dramctl_grant_r) begin
      bus_cmd = bus_cmd | dramctl_bus_cmd;
      bus_tag = bus_tag | dramctl_bus_tag;
      bus_addr = bus_addr | dramctl_bus_addr;
      bus_data = bus_data | dramctl_bus_data;
    end
    if(rom_grant_r) begin
      bus_cmd = bus_cmd | rom_bus_cmd;
      bus_tag = bus_tag | rom_bus_tag;
      bus_addr = bus_addr | rom_bus_addr;
      bus_data = bus_data | rom_bus_data;
    end
  end

  always @(posedge clk)
    if(bus_valid) begin
      if(bus_cmd == `CMD_FILL || bus_cmd == `CMD_FLUSH)
        top.tb_log_bus_data(bus_cycle_r, bus_data);
      if(bus_cycle_r == 7)
        top.tb_log_bus_cycle(
          bus_nack,
          bus_hit,
          bus_cmd,
          bus_tag,
          bus_addr);
    end

endmodule
