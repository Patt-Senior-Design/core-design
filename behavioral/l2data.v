// l2 data store
module l2data(
  input         clk,
  input         rst,

  // l2tag interface
  input         l2tag_req_valid,
  input [1:0]   l2tag_req_op,
  input         l2tag_req_cmd_valid,
  input         l2tag_req_cmd_noinv,
  input [2:0]   l2tag_req_cmd,
  input [31:3]  l2tag_req_addr,
  input [3:0]   l2tag_req_way,
  input [7:0]   l2tag_req_wmask,
  input [63:0]  l2tag_req_wdata,
  output        l2data_req_ready,
  output        l2data_req_wdata_ready,

  input         l2tag_snoop_valid,
  input [4:0]   l2tag_snoop_tag,
  input [31:6]  l2tag_snoop_addr,
  input [3:0]   l2tag_snoop_way,
  input         l2tag_snoop_wen,
  input [63:0]  l2tag_snoop_wdata,
  output        l2data_snoop_ready,

  input         l2tag_inv_valid,
  input [31:6]  l2tag_inv_addr,
  output        l2data_flush_hit,

  // l2trans interface
  output        l2data_req_valid,
  output        l2data_req_noinv,
  output [2:0]  l2data_req_cmd,
  output [31:6] l2data_req_addr,
  output [63:0] l2data_req_data,
  input         l2trans_l2data_req_ready,

  output        l2data_snoop_valid,
  output [4:0]  l2data_snoop_tag,
  output [31:6] l2data_snoop_addr,
  output [63:0] l2data_snoop_data,
  input         l2trans_l2data_snoop_ready,

  // l2 interface
  output        l2_resp_valid,
  output        l2_resp_error,
  output [63:0] l2_resp_rdata,
  input         resp_ready,

  output        l2data_idle);

  // one-hot signal to index
  function automatic [8:0] addr2set(
    input [31:6] addr);

    addr2set = addr[14:6];
  endfunction

  function automatic [1:0] oh2idx(
    input [3:0] onehot);

    begin
      oh2idx[1] = onehot[2] | onehot[3];
      oh2idx[0] = onehot[1] | onehot[3];
    end
  endfunction

  // stage 0 latches
  reg         s0_req_valid_r;
  reg [1:0]   s0_req_op_r;
  reg         s0_req_cmd_valid_r;
  reg         s0_req_cmd_noinv_r;
  reg [2:0]   s0_req_cmd_r;
  reg [31:3]  s0_req_addr_r;
  reg [3:0]   s0_req_way_r;
  reg [7:0]   s0_req_wmask_r;
  reg [63:0]  s0_req_wdata_r;

  reg [2:0]   s0_req_beat_r;

  reg         s0_snoop_valid_r;
  reg [4:0]   s0_snoop_tag_r;
  reg [31:6]  s0_snoop_addr_r;
  reg [3:0]   s0_snoop_way_r;
  reg         s0_snoop_wen_r;
  reg [63:0]  s0_snoop_wdata_r;

  reg [2:0]   s0_snoop_beat_r;

  // stage 1 latches
  reg         s1_req_valid_r;
  reg         s1_req_cmd_valid_r;
  reg         s1_req_cmd_noinv_r;
  reg [2:0]   s1_req_cmd_r;
  reg [31:6]  s1_req_addr_r;
  reg [3:0]   s1_req_bank_r;

  reg         s1_snoop_valid_r;
  reg [4:0]   s1_snoop_tag_r;
  reg [31:6]  s1_snoop_addr_r;
  reg [3:0]   s1_snoop_bank_r;

  // stage 2 latches
  reg         s2_req_valid_r;
  reg         s2_req_cmd_valid_r;
  reg         s2_req_cmd_noinv_r;
  reg [2:0]   s2_req_cmd_r;
  reg [31:6]  s2_req_addr_r;
  reg [3:0]   s2_req_bank_r;

  reg         s2_snoop_valid_r;
  reg [4:0]   s2_snoop_tag_r;
  reg [31:6]  s2_snoop_addr_r;
  reg [3:0]   s2_snoop_bank_r;

  reg [3:0]   bank_in_valid;
  reg [11:0]  bank_addr;
  reg         bank_wen;
  reg [7:0]   bank_wmask;
  reg [63:0]  bank_wdata;
  wire [63:0] bank_rdata [0:3];

  // derived signals
  wire s0_req_ren, s0_req_wen, s0_req_overwrite;
  assign s0_req_ren = s0_req_op_r[0];
  assign s0_req_wen = s0_req_op_r != `OP_RD;
  assign s0_req_overwrite = s0_req_op_r == `OP_WR64;

  wire req_burst;
  assign req_burst = s0_req_cmd_valid_r ? (s0_req_cmd_r == `CMD_FLUSH)
                                        : (s0_req_ren | s0_req_overwrite);

  wire [3:0] req_bank_sel, snoop_bank_sel;
  assign req_bank_sel = 4'b0001 << (req_burst ? s0_req_beat_r[1:0]
                                              : s0_req_addr_r[4:3]);
  assign snoop_bank_sel = 4'b0001 << s0_snoop_beat_r[1:0];

  wire [11:0] req_bank_addr, snoop_bank_addr;
  assign req_bank_addr = {oh2idx(s0_req_way_r),s0_req_addr_r[14:6],
                          req_burst ? s0_req_beat_r[2] : s0_req_addr_r[5]};
  assign snoop_bank_addr = {oh2idx(s0_snoop_way_r),s0_snoop_addr_r[14:6],
                            s0_snoop_beat_r[2]};

  wire [63:0] req_rdata, snoop_rdata;
  assign req_rdata = bank_rdata[oh2idx(s2_req_bank_r)];
  assign snoop_rdata = bank_rdata[oh2idx(s2_snoop_bank_r)];

  wire s2_req_stall;
  assign s2_req_stall = l2_resp_valid & ~resp_ready;

  wire s0_req_issue, s0_snoop_issue;
  assign s0_req_issue = s0_req_valid_r & (~s2_req_stall | s0_req_wen) &
                        (l2trans_l2data_req_ready | (s0_req_beat_r != 0)) &
                        ~s0_snoop_issue;
  assign s0_snoop_issue = s0_snoop_valid_r &
                          (s0_snoop_wen_r |
                           l2trans_l2data_snoop_ready |
                           (s0_snoop_beat_r != 0));

  wire s0_inv_hit, s1_inv_hit, s2_inv_hit;
  assign s0_inv_hit = s0_req_valid_r & s0_req_cmd_valid_r &
                      (s0_req_addr_r[31:6] == l2tag_inv_addr);
  assign s1_inv_hit = s1_req_valid_r & s1_req_cmd_valid_r &
                      (s1_req_addr_r == l2tag_inv_addr);
  assign s2_inv_hit = s2_req_valid_r & s2_req_cmd_valid_r &
                      (s2_req_addr_r == l2tag_inv_addr);

  wire s0_flush_hit, s1_flush_hit, s2_flush_hit;
  assign s0_flush_hit = s0_inv_hit & (s0_req_cmd_r == `CMD_FLUSH);
  assign s1_flush_hit = s1_inv_hit & (s1_req_cmd_r == `CMD_FLUSH);
  assign s2_flush_hit = s2_inv_hit & (s2_req_cmd_r == `CMD_FLUSH);

  wire s0_upgr_hit, s1_upgr_hit, s2_upgr_hit;
  assign s0_upgr_hit = l2tag_inv_valid & s0_inv_hit &
                       (s0_req_cmd_r == `CMD_BUSUPGR) & ~s0_req_cmd_noinv_r;
  assign s1_upgr_hit = l2tag_inv_valid & s1_inv_hit &
                       (s1_req_cmd_r == `CMD_BUSUPGR) & ~s1_req_cmd_noinv_r;
  assign s2_upgr_hit = l2tag_inv_valid & s2_inv_hit &
                       (s2_req_cmd_r == `CMD_BUSUPGR) & ~s2_req_cmd_noinv_r;

  // l2tag interface
  assign l2data_req_ready = ~s0_req_valid_r |
                            (s0_req_issue &
                             (~req_burst |
                              (~(s0_req_ren & s0_req_wen) &
                               (s0_req_beat_r == 7))));
  assign l2data_req_wdata_ready = ~s0_req_valid_r | s0_req_issue;
  assign l2data_snoop_ready = ~s0_snoop_valid_r | (s0_snoop_beat_r == 7);

  assign l2data_flush_hit = s0_flush_hit | s1_flush_hit | s2_flush_hit;

  // l2trans interface
  assign l2data_req_valid = s2_req_valid_r & s2_req_cmd_valid_r;
  assign l2data_req_noinv = s1_req_cmd_noinv_r;
  assign l2data_req_cmd = s2_upgr_hit ? `CMD_BUSRDX : s2_req_cmd_r;
  assign l2data_req_addr = s2_req_addr_r;
  assign l2data_req_data = req_rdata;

  assign l2data_snoop_valid = s2_snoop_valid_r;
  assign l2data_snoop_tag = s2_snoop_tag_r;
  assign l2data_snoop_addr = s2_snoop_addr_r;
  assign l2data_snoop_data = snoop_rdata;

  // l2 interface
  assign l2_resp_valid = s2_req_valid_r & ~s2_req_cmd_valid_r;
  assign l2_resp_error = 0;
  assign l2_resp_rdata = req_rdata;

  assign l2data_idle = ~s0_req_valid_r & ~s1_req_valid_r & ~s2_req_valid_r;

  // bank signals
  always @(*)
    if(s0_snoop_issue) begin
      bank_in_valid = snoop_bank_sel;
      bank_addr = snoop_bank_addr;
      bank_wen = s0_snoop_wen_r;
      bank_wmask = 8'b11111111;
      bank_wdata = s0_snoop_wdata_r;
    end else if(s0_req_issue) begin
      bank_in_valid = (~s0_req_cmd_valid_r | req_burst) ? req_bank_sel : 0;
      bank_addr = req_bank_addr;
      bank_wen = s0_req_wen & ~s0_req_ren;
      bank_wmask = s0_req_overwrite ? 8'b11111111 : s0_req_wmask_r;
      bank_wdata = s0_req_wdata_r;
    end else
      bank_in_valid = 0;

  genvar i;
  generate
    for(i = 0; i < 4; i=i+1) begin : banks
      l2bank bank(
        .clk(clk),
        .rst(rst),
        .l2data_bank_valid(bank_in_valid[i]),
        .l2data_bank_wen(bank_wen),
        .l2data_bank_addr(bank_addr),
        .l2data_bank_wmask(bank_wmask),
        .l2data_bank_wdata(bank_wdata),
        .l2bank_rdata(bank_rdata[i]));
    end
  endgenerate

  always @(posedge clk)
    if(rst)
      s0_req_valid_r <= 0;
    else if(l2data_req_ready) begin
      s0_req_valid_r <= l2tag_req_valid;
      if(l2tag_req_valid) begin
        s0_req_op_r        <= l2tag_req_op;
        s0_req_cmd_valid_r <= l2tag_req_cmd_valid;
        s0_req_cmd_noinv_r <= l2tag_req_cmd_noinv;
        s0_req_cmd_r       <= l2tag_req_cmd;
        s0_req_addr_r      <= l2tag_req_addr;
        s0_req_way_r       <= l2tag_req_way;
      end
    end else begin
      if(s0_req_issue & (s0_req_beat_r == 7))
        // (mark) burst read complete, deassert s0_req_ren and do word write
        s0_req_op_r[0] <= 0;
      if(s0_upgr_hit)
        s0_req_cmd_r <= `CMD_BUSRDX;
    end

  always @(posedge clk)
    if(l2data_req_wdata_ready) begin
      s0_req_wmask_r <= l2tag_req_wmask;
      s0_req_wdata_r <= l2tag_req_wdata;
    end

  always @(posedge clk)
    if(rst)
      s0_req_beat_r <= 0;
    else if(s0_req_issue & req_burst)
      s0_req_beat_r <= s0_req_beat_r + 1;

  always @(posedge clk)
    if(rst)
      s0_snoop_valid_r <= 0;
    else if(l2data_snoop_ready) begin
      s0_snoop_valid_r <= l2tag_snoop_valid;
      if(l2tag_snoop_valid) begin
        s0_snoop_tag_r   <= l2tag_snoop_tag;
        s0_snoop_addr_r  <= l2tag_snoop_addr;
        s0_snoop_way_r   <= l2tag_snoop_way;
        s0_snoop_wen_r   <= l2tag_snoop_wen;
      end
    end

  always @(posedge clk)
    s0_snoop_wdata_r <= l2tag_snoop_wdata;

  always @(posedge clk)
    if(rst)
      s0_snoop_beat_r <= 0;
    else if(s0_snoop_issue)
      s0_snoop_beat_r <= s0_snoop_beat_r + 1;

  always @(posedge clk)
    if(rst)
      s1_req_valid_r <= 0;
    else if(~s2_req_stall) begin
      s1_req_valid_r <= s0_req_issue & s0_req_ren;
      if(s0_req_issue & s0_req_ren) begin
        s1_req_cmd_valid_r <= s0_req_cmd_valid_r;
        s1_req_cmd_noinv_r <= s0_req_cmd_noinv_r;
        s1_req_cmd_r       <= s0_upgr_hit ? `CMD_BUSRDX : s0_req_cmd_r;
        s1_req_addr_r      <= s0_req_addr_r[31:6];
        s1_req_bank_r      <= req_bank_sel;
      end
    end else if(s1_upgr_hit)
      s1_req_cmd_r <= `CMD_BUSRDX;

  always @(posedge clk)
    if(rst)
      s1_snoop_valid_r <= 0;
    else begin
      s1_snoop_valid_r <= s0_snoop_issue & ~s0_snoop_wen_r;
      if(s0_snoop_issue & ~s0_snoop_wen_r) begin
        s1_snoop_tag_r  <= s0_snoop_tag_r;
        s1_snoop_addr_r <= s0_snoop_addr_r;
        s1_snoop_bank_r <= snoop_bank_sel;
      end
    end

  always @(posedge clk)
    if(rst)
      s2_req_valid_r <= 0;
    else if(~s2_req_stall) begin
      s2_req_valid_r <= s1_req_valid_r;
      if(s1_req_valid_r) begin
        s2_req_cmd_valid_r <= s1_req_cmd_valid_r;
        s2_req_cmd_noinv_r <= s1_req_cmd_noinv_r;
        s2_req_cmd_r       <= s1_upgr_hit ? `CMD_BUSRDX : s1_req_cmd_r;
        s2_req_addr_r      <= s1_req_addr_r;
        s2_req_bank_r      <= s1_req_bank_r;
      end
    end else if(s2_upgr_hit)
      s2_req_cmd_r <= `CMD_BUSRDX;

  always @(posedge clk)
    if(rst)
      s2_snoop_valid_r <= 0;
    else begin
      s2_snoop_valid_r <= s1_snoop_valid_r;
      if(s1_snoop_valid_r) begin
        s2_snoop_tag_r   <= s1_snoop_tag_r;
        s2_snoop_addr_r  <= s1_snoop_addr_r;
        s2_snoop_bank_r  <= s1_snoop_bank_r;
      end
    end

endmodule
