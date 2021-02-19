// l2 bus transmitter
module l2trans(
  input             clk,
  input             rst,

  // l2data interface
  input             l2data_req_valid,
  input [2:0]       l2data_req_cmd,
  input [31:6]      l2data_req_addr,
  input [63:0]      l2data_req_data,
  output            l2trans_l2data_req_ready,

  input             l2data_snoop_valid,
  input [4:0]       l2data_snoop_tag,
  input [31:6]      l2data_snoop_addr,
  input [63:0]      l2data_snoop_data,
  output            l2trans_l2data_snoop_ready,

  // l2tag interface
  output            l2trans_valid,
  output [2:0]      l2trans_tag,

  // bus interface
  output            l2_bus_req,
  output reg [2:0]  l2_bus_cmd,
  output reg [4:0]  l2_bus_tag,
  output reg [31:6] l2_bus_addr,
  output reg [63:0] l2_bus_data,
  input             bus_l2_grant,

  // we have to examine the current cmd as well
  input             bus_valid,
  input             bus_nack,
  input [2:0]       bus_cmd,
  input [4:0]       bus_tag,
  input [31:6]      bus_addr);

  // stages of transmitting a bus command:
  // 1. assert bus_req, watch bus_grant
  // 2. while command is on bus, watch bus_nack
  // due to tag size, we support a max of 8 pending commands

  reg           req_valid_r;
  reg           req_sent_r;
  reg [2:0]     req_cmd_r;
  reg [31:6]    req_addr_r;

  reg           req_data_ready_r;
  reg [2:0]     req_data_index_r;
  reg [63:0]    req_data [0:7];

  reg           snoop_valid_r;
  reg           snoop_sent_r;
  reg [4:0]     snoop_tag_r;
  reg [31:6]    snoop_addr_r;

  reg           snoop_data_ready_r;
  reg [2:0]     snoop_data_index_r;
  reg [63:0]    snoop_data [0:7];

  reg [2:0]     req_tag_r;
  reg [2:0]     bus_cycle_r;

  wire          req_flush;
  assign req_flush = req_cmd_r == `CMD_FLUSH;

  wire          req_data_wr_beat, snoop_data_wr_beat;
  assign req_data_wr_beatt = l2data_req_valid &
                             (l2trans_l2data_req_ready |
                              (req_data_index_r != 0));
  assign snoop_data_wr_beat = l2data_snoop_valid &
                              (l2trans_l2data_snoop_ready |
                               (snoop_data_index_r != 0));

  wire          req_data_rd_beat, snoop_data_rd_beat;
  assign req_data_rd_beat = req_valid_r & req_sent_r & req_flush;
  assign snoop_data_rd_beat = snoop_valid_r & snoop_sent_r;

  wire          upgr_conflict;
  assign upgr_conflict = req_valid_r & ~snoop_valid_r &
                         (req_cmd_r == `CMD_BUSUPGR) &
                         bus_valid & ~bus_nack &
                         ((bus_cmd == `CMD_BUSUPGR) | (bus_cmd == `CMD_BUSRDX)) &
                         (bus_addr == req_addr_r);

  // l2data interface
  assign l2trans_l2data_req_ready = ~req_valid_r |
                                    (req_sent_r & ~bus_nack &
                                     (bus_cycle_r == 7));
  assign l2trans_l2data_snoop_ready = ~snoop_valid_r |
                                      (snoop_sent_r & (bus_cycle_r == 7));

  // l2tag interface
  assign l2trans_valid = req_valid_r & req_sent_r &
                         ~bus_nack & (bus_cycle_r == 7);;
  assign l2trans_tag = req_tag_r;

  // bus interface
  assign l2_bus_req = (req_valid_r & ~req_sent_r &
                       (~req_flush | req_data_ready_r)) |
                      (snoop_valid_r & ~snoop_sent_r &
                       snoop_data_ready_r);

  always @(*)
    if(snoop_valid_r) begin
      l2_bus_cmd = `CMD_FLUSH;
      l2_bus_tag = snoop_tag_r;
      l2_bus_addr = snoop_addr_r;
      l2_bus_data = req_data[req_data_index_r[2:0]];
    end else begin
      l2_bus_cmd = upgr_conflict ? `CMD_BUSRDX : req_cmd_r;
      l2_bus_tag = {`BUSID_L2,req_tag_r};
      l2_bus_addr = req_addr_r;
      l2_bus_data = snoop_data[snoop_data_index_r[2:0]];
    end

  // bus_cycle_r
  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_r + 1;

  always @(posedge clk)
    if(rst)
      req_valid_r <= 0;
    else if(l2trans_l2data_req_ready) begin
      req_valid_r <= l2data_req_valid;
      req_sent_r <= 0;
      if(l2data_req_valid) begin
        req_cmd_r <= l2data_req_cmd;
        req_addr_r <= l2data_req_addr;
      end
    end else if(req_valid_r & ~snoop_valid_r &
                bus_l2_grant & (bus_cycle_r == 7))
      req_sent_r <= 1;

  always @(posedge clk)
    if(rst) begin
      req_data_ready_r <= 0;
      req_data_index_r <= 0;
    end else if(req_data_wr_beat) begin
      if(req_data_index_r == 7)
        req_data_ready_r <= 1;
      req_data_index_r <= req_data_index_r + 1;
    end else if(req_data_rd_beat) begin
      if((req_data_index_r == 7) & ~bus_nack)
        req_data_ready_r <= 0;
      req_data_index_r <= req_data_index_r + 1;
    end

  always @(posedge clk)
    if(rst)
      req_tag_r <= 0;
    else if(req_valid_r & req_sent_r & ~bus_nack & (bus_cycle_r == 7))
      req_tag_r <= req_tag_r + 1;

  always @(posedge clk)
    if(rst)
      snoop_valid_r <= 0;
    else if(l2trans_l2data_snoop_ready) begin
      snoop_valid_r <= l2data_snoop_valid;
      snoop_sent_r <= 0;
      if(l2data_snoop_valid) begin
        snoop_tag_r <= l2data_snoop_tag;
        snoop_addr_r <= l2data_snoop_addr;
      end
    end else if(snoop_valid_r &
                bus_l2_grant & (bus_cycle_r == 7))
      snoop_sent_r <= 1;

  always @(posedge clk)
    if(rst) begin
      snoop_data_ready_r <= 0;
      snoop_data_index_r <= 0;
    end else if(snoop_data_wr_beat) begin
      if(snoop_data_index_r == 7)
        snoop_data_ready_r <= 1;
      snoop_data_index_r <= snoop_data_index_r + 1;
    end else if(snoop_data_rd_beat) begin
      if(snoop_data_index_r == 7)
        snoop_data_ready_r <= 0;
      snoop_data_index_r <= snoop_data_index_r + 1;
    end

endmodule
