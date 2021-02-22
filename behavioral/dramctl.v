`include "buscmd.vh"

// dram controller
module dramctl(
  input             clk,
  input             rst,

  // bus interface
  input             bus_valid,
  input             bus_nack,
  input             bus_hit,
  input [2:0]       bus_cmd,
  input [4:0]       bus_tag,
  input [31:6]      bus_addr,
  input [63:0]      bus_data,

  output reg        dramctl_bus_req,
  output reg [2:0]  dramctl_bus_cmd,
  output reg [4:0]  dramctl_bus_tag,
  output reg [31:6] dramctl_bus_addr,
  output reg [63:0] dramctl_bus_data,
  output reg        dramctl_bus_nack,
  input             bus_dramctl_grant);

  // memory map constants
  localparam
    RAM_BASE = 32'h20000000/4,
    RAM_SIZE = (128*1024*1024)/4;

  reg cmd_relevant, cmd_write;
  always @(*) begin
    cmd_relevant = bus_valid & ~bus_nack & (~bus_hit | (bus_cmd == `CMD_FLUSH)) &
                   ({bus_addr,4'b0} >= RAM_BASE) &
                   ({bus_addr,4'b0} < (RAM_BASE+RAM_SIZE));
    case(bus_cmd)
      `CMD_BUSRD: cmd_write = 0;
      `CMD_BUSRDX: cmd_write = 0;
      `CMD_FLUSH: cmd_write = 1;
      default: cmd_relevant = 0;
    endcase
  end

  reg [2:0] bus_cycle_r;
  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_r + 1;

  reg [64*8-1:0] bus_wdata_r;
  always @(posedge clk)
    bus_wdata_r[bus_cycle_r*64+:64] <= bus_data;

  // cycle 0 of rdata is handled below
  reg [64*8-1:0] dram_rdata_r;
  always @(posedge clk)
    if(bus_cycle_r != 0)
      dramctl_bus_data <= dram_rdata_r[bus_cycle_r*64+:64];

  reg dramclk;
  initial
    $dramsim$init(dramclk);

  wire [31:2] mem_addr;
  assign mem_addr = {bus_addr,4'b0} - RAM_BASE;

  reg        dramsim_ready;
  reg        cmd_valid_r;
  reg        cmd_write_r;
  reg [4:0]  cmd_tag_r;
  reg [31:2] cmd_addr_r;
  reg [4:0]  resp_tag_r;
  reg [31:2] resp_addr_r;

  wire [31:2] resp_addr;
  assign resp_addr = resp_addr_r + RAM_BASE;

  always @(posedge clk)
    if(rst) begin
      dramctl_bus_req <= 0;
      dramctl_bus_nack <= 0;
    end else if(bus_cycle_r == 3) begin
      if(cmd_relevant)
        dramsim_ready = $dramsim$cmdready(cmd_write, mem_addr);
      else
        dramsim_ready = 1;

      dramctl_bus_nack <= ~dramsim_ready;
      cmd_valid_r <= cmd_relevant & dramsim_ready;
      cmd_write_r <= cmd_write;
      cmd_tag_r <= bus_tag;
      cmd_addr_r <= mem_addr;
    end else if(bus_cycle_r == 0) begin
      // now that we have gathered any wdata, send request
      if(cmd_valid_r)
        $dramsim$cmddata(cmd_write_r, cmd_tag_r, cmd_addr_r, bus_wdata_r);
    end else if(bus_cycle_r == 7) begin
      // previous cycle
      if(dramctl_bus_req & bus_dramctl_grant) begin
        $dramsim$respdata(resp_tag_r, resp_addr_r, dram_rdata_r);
        dramctl_bus_tag <= resp_tag_r;
        dramctl_bus_addr <= resp_addr[31:6];
        dramctl_bus_data <= dram_rdata_r[63:0];
      end
      // this cycle
      dramctl_bus_req <= $dramsim$respready();
      dramctl_bus_cmd <= `CMD_FILL;
    end

endmodule
