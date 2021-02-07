`include "buscmd.vh"

// read-only memory
module rom(
  input             clk,
  input             rst,

  // bus interface
  input             bus_valid,
  input             bus_nack,
  input             bus_hit,
  input [2:0]       bus_cmd,
  input [4:0]       bus_tag,
  input [31:2]      bus_addr,
  input [63:0]      bus_data,

  output reg        rom_bus_req,
  output reg [2:0]  rom_bus_cmd,
  output reg [4:0]  rom_bus_tag,
  output reg [31:2] rom_bus_addr,
  output reg [63:0] rom_bus_data,
  output            rom_bus_nack,
  input             bus_rom_grant);

  // memory map constants
  localparam
    ROM_BASE = 32'h10000000/4,
    ROM_SIZE = (64*1024)/4;

  reg [2:0]  bus_cycle_r;
  reg        cmd_valid_r;
  reg [4:0]  cmd_tag_r;
  reg [31:2] cmd_addr_r;
  reg        resp_valid_r;

  wire cmd_relevant;
  assign cmd_relevant = bus_valid & ~bus_nack & ~bus_hit &
                        ((bus_cmd == `CMD_BUSRD) | (bus_cmd == `CMD_BUSRDX)) &
                        (bus_addr >= ROM_BASE) & (bus_addr < (ROM_BASE+ROM_SIZE));

  wire [2:0] bus_cycle_n;
  assign bus_cycle_n = bus_cycle_r + 1;

  wire [31:2] mem_addr;
  assign mem_addr = {rom_bus_addr[31:6],bus_cycle_r,1'b0};

  always @(*)
    if(resp_valid_r) begin
      top.mem_read(mem_addr, rom_bus_data[31:0]);
      top.mem_read(mem_addr+1, rom_bus_data[63:32]);
    end

  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_n;

  always @(posedge clk)
    if(rst) begin
      rom_bus_req <= 0;
      cmd_valid_r <= 0;
      resp_valid_r <= 0;
    end else if(bus_cycle_r == 0) begin
      rom_bus_req <= cmd_relevant | cmd_valid_r;
      rom_bus_cmd <= `CMD_FILL;
      if(cmd_relevant & ~cmd_valid_r) begin
        cmd_valid_r <= 1;
        cmd_tag_r <= bus_tag;
        cmd_addr_r <= bus_addr;
      end
    end else if(bus_cycle_r == 7)
      if(rom_bus_req & bus_rom_grant) begin
        cmd_valid_r <= 0;
        resp_valid_r <= cmd_valid_r;
        rom_bus_tag <= cmd_tag_r;
        rom_bus_addr <= cmd_addr_r;
      end

  assign rom_bus_nack = 0;

endmodule
