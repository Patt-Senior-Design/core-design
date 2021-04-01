// l2 bus receiver
module l2tag #(
  parameter BUSID = `BUSID_L2
  )(
  input            clk,
  input            rst,

  // l2reqfifo interface
  input            req_valid,
  input [1:0]      req_op,
  input [31:2]     req_addr,
  input [7:0]      req_wmask,
  input [63:0]     req_wdata,
  output           l2_req_ready,

  // bus interface (in)
  input            bus_valid,
  input            bus_nack,
  input [2:0]      bus_cmd,
  input [4:0]      bus_tag,
  input [31:6]     bus_addr,
  input [63:0]     bus_data,

  // l2data interface
  output           l2tag_req_valid,
  output [1:0]     l2tag_req_op,
  output           l2tag_req_cmd_valid,
  output           l2tag_req_cmd_noinv,
  output reg [2:0] l2tag_req_cmd,
  output [31:3]    l2tag_req_addr,
  output [3:0]     l2tag_req_way,
  output [7:0]     l2tag_req_wmask,
  output [63:0]    l2tag_req_wdata,
  input            l2data_req_ready,
  input            l2data_req_wdata_ready,

  output           l2tag_snoop_valid,
  output [4:0]     l2tag_snoop_tag,
  output [31:6]    l2tag_snoop_addr,
  output [3:0]     l2tag_snoop_way,
  output           l2tag_snoop_wen,
  output [63:0]    l2tag_snoop_wdata,
  input            l2data_snoop_ready,

  input            l2data_flush_hit,

  // l2trans interface
  input            l2trans_flush_hit,

  input            l2trans_valid,
  input [2:0]      l2trans_tag,
  input            l2trans_upgr_hit,

  // l2 interface
  output           l2tag_inv_valid,
  output [31:6]    l2tag_inv_addr,
  input            invfifo_ready,

  output           l2tag_idle,

  // bus interface (out)
  output           l2_bus_hit,
  output           l2_bus_nack);

  function automatic [8:0] addr2set(
    input [31:6] addr);

    addr2set = addr[14:6];
  endfunction

  function automatic [16:0] addr2tag(
    input [31:6] addr);

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

  // 3*4 state bits, 3 lru bits, 17*4 tag bits
  reg [11:0] tagmem_state [0:511];
  reg [2:0]  tagmem_lru [0:511];
  reg [67:0] tagmem_tag [0:511];

  // stage 0 latches
  reg [2:0]  s0_req_beat_r;

  reg        s0_req_valid_r;
  reg        s0_req_noop_r;
  reg [1:0]  s0_req_op_r;
  reg [31:2] s0_req_addr_r;
  reg [7:0]  s0_req_wmask_r;
  reg [63:0] s0_req_wdata_r;

  reg        s0_snoop_valid_r;
  reg [2:0]  s0_snoop_cmd_r;
  reg [4:0]  s0_snoop_tag_r;
  reg [31:6] s0_snoop_addr_r;
  reg [63:0] s0_snoop_data_r;

  // stage 1 latches
  reg        s1_req_valid_r;
  reg        s1_req_noop_r;
  reg [1:0]  s1_req_op_r;
  reg [31:3] s1_req_addr_r;
  reg [7:0]  s1_req_wmask_r;
  reg [63:0] s1_req_wdata_r;

  reg        s1_req_tag_stale_r;
  reg [3:0]  s1_req_tagmem_way_r;
  reg [2:0]  s1_req_tagmem_state_r;
  reg [2:0]  s1_req_tagmem_lru_r;
  reg [3:0]  s1_req_fill_way_r;
  reg [16:0] s1_req_fill_tag_r;

  reg        s1_req_miss_r;
  reg        s1_req_upgr_r;
  reg        s1_req_evict_r;

  reg        s1_snoop_valid_r;
  reg [2:0]  s1_snoop_cmd_r;
  reg [4:0]  s1_snoop_tag_r;
  reg [31:6] s1_snoop_addr_r;
  reg [63:0] s1_snoop_data_r;

  reg [3:0]  tagmem_way_r;
  reg [11:0] tagmem_states_r;
  reg [2:0]  tagmem_lru_r;
  reg [67:0] tagmem_tags_r;

  // pending BusRd/BusRdX response
  reg        pend_valid_r;
  reg [2:0]  pend_cmd_r;
  reg        pend_tag_valid_r;
  reg [2:0]  pend_tag_r;

  reg        bus_hit_r;
  reg        bus_nack_r;
  reg [2:0]  bus_cycle_r;

  // derived signals
  wire s1_req_wen, s1_req_overwrite;
  assign s1_req_wen = s1_req_op_r != `OP_RD;
  assign s1_req_overwrite = s1_req_op_r == `OP_WR64;

  wire       snoop_en, snoop_valid;
  assign snoop_en = bus_cycle_r == 0;
  assign snoop_valid = bus_valid &
                       ((bus_tag[4:3] != BUSID) |
                        (bus_cmd == `CMD_FILL) | (bus_cmd == `CMD_FLUSH));

  wire [2:0] tagmem_way_state;
  assign tagmem_way_state = tagmem_states_r[oh2idx(tagmem_way_r)*3+:3];

  wire tagmiss;
  assign tagmiss = ~|tagmem_way_r;

  wire upgr_shared;
  assign upgr_shared = s1_req_valid_r & s1_req_wen &
                       ((tagmem_way_state == `STATE_S) |
                        (tagmem_way_state == `STATE_F));

  integer   j;
  reg [3:0] tagmem_valid;
  always @(*)
    for(j = 0; j < 4; j=j+1)
      tagmem_valid[j] = tagmem_states_r[j*3+:3] != `STATE_I;

  reg [3:0] fill_way;
  always @(*)
    if(~&tagmem_valid)
      // there is an invalid way, use that one
      casez(tagmem_valid)
        4'b???0: fill_way = 4'b0001;
        4'b??01: fill_way = 4'b0010;
        4'b?011: fill_way = 4'b0100;
        4'b0111: fill_way = 4'b1000;
      endcase
    else
      // decode lru bits
      casez(tagmem_lru_r)
        3'b0?0: fill_way = 4'b0001;
        3'b0?1: fill_way = 4'b0010;
        3'b10?: fill_way = 4'b0100;
        3'b11?: fill_way = 4'b1000;
      endcase

  wire [2:0]  fill_state;
  wire [16:0] fill_tag;
  assign fill_state = tagmem_states_r[oh2idx(fill_way)*3+:3];
  assign fill_tag = tagmem_tags_r[oh2idx(fill_way)*17+:17];

  wire evict;
  assign evict = s1_req_valid_r & tagmiss & (fill_state == `STATE_M);

  wire flush;
  assign flush = s1_snoop_valid_r & ~tagmiss &
                 ((s1_snoop_cmd_r == `CMD_BUSRD) |
                  ((s1_snoop_cmd_r == `CMD_BUSRDX) & invfifo_ready) |
                  ((s1_snoop_cmd_r == `CMD_BUSUPGR) & invfifo_ready &
                   (tagmem_way_state == `STATE_M)));

  wire fill;
  assign fill = pend_valid_r & pend_tag_valid_r & s1_snoop_valid_r &
                (s1_snoop_tag_r == {BUSID,pend_tag_r});

  wire s0_req_stall;
  reg  s1_req_stall;
  assign s0_req_stall = s0_snoop_valid_r | s1_req_stall;

  always @(*) begin
    s1_req_stall = 0;
    if(s1_req_valid_r) begin
      s1_req_stall = s1_req_stall | s1_req_miss_r;
      if(s1_req_noop_r)
        s1_req_stall = s1_req_stall | ~l2data_req_wdata_ready;
      else begin
        s1_req_stall = s1_req_stall | ~l2data_req_ready;
        if(~s1_req_tag_stale_r)
          s1_req_stall = s1_req_stall | tagmiss | upgr_shared;
      end
    end
  end

  wire       lru_wen;
  wire [8:0] lru_wset;
  wire [2:0] lru_wdata;
  assign lru_wen = s1_req_valid_r & ~s1_req_noop_r & ~s1_req_stall;
  assign lru_wset = addr2set(s1_req_addr_r[31:6]);
  assign lru_wdata = s1_req_tag_stale_r
                     ? next_lru(s1_req_tagmem_way_r, s1_req_tagmem_lru_r)
                     : next_lru(tagmem_way_r, tagmem_lru_r);

  wire pend_conflict;
  assign pend_conflict = pend_valid_r & pend_tag_valid_r &
                         ((pend_cmd_r == `CMD_BUSRD) |
                          (pend_cmd_r == `CMD_BUSRDX)) &
                         s1_snoop_valid_r &
                         ((s1_snoop_cmd_r == `CMD_BUSRD) |
                          (s1_snoop_cmd_r == `CMD_BUSRDX) |
                          (s1_snoop_cmd_r == `CMD_BUSUPGR)) &
                         (s1_snoop_addr_r == s1_req_addr_r[31:6]);

  wire flush_conflict;
  assign flush_conflict = s1_snoop_valid_r &
                          ((s1_snoop_cmd_r == `CMD_BUSRD) |
                           (s1_snoop_cmd_r == `CMD_BUSRDX) |
                           (s1_snoop_cmd_r == `CMD_BUSUPGR)) &
                          (l2data_flush_hit | l2trans_flush_hit);

  wire s0_req_noop, s0_req_noop_beat;
  assign s0_req_noop = ((s0_req_valid_r & (s0_req_op_r == `OP_WR64)) |
                        (s0_req_beat_r != 0)) & (s0_req_beat_r != 7);
  assign s0_req_noop_beat = ~s0_req_stall &
                            ((s0_req_valid_r & (s0_req_op_r == `OP_WR64)) |
                             (s0_req_beat_r != 0));

  // l2reqfifo interface
  assign l2_req_ready = ~s0_req_stall;
  assign l2_req_wdata_ready = l2_req_ready;

  // l2data interface
  assign l2tag_req_valid = (s1_req_valid_r & ~s1_req_stall) |
                           (s1_req_miss_r & ~pend_valid_r);
  assign l2tag_req_op = s1_req_miss_r ? `OP_RD : s1_req_op_r;
  assign l2tag_req_cmd_valid = s1_req_miss_r;
  assign l2tag_req_cmd_noinv = s1_req_overwrite;
  assign l2tag_req_addr = s1_req_evict_r
                          ? {s1_req_fill_tag_r,addr2set(s1_req_addr_r[31:6]),3'b0}
                          : s1_req_addr_r;
  assign l2tag_req_way = s1_req_evict_r
                         ? s1_req_fill_way_r
                         : ((s1_req_miss_r | s1_req_tag_stale_r | s1_req_noop_r)
                            ? s1_req_tagmem_way_r : tagmem_way_r);
  assign l2tag_req_wmask = s1_req_wmask_r;
  assign l2tag_req_wdata = s1_req_wdata_r;

  always @(*)
    if(s1_req_evict_r)
      l2tag_req_cmd = `CMD_FLUSH;
    else if(s1_req_upgr_r)
      l2tag_req_cmd = `CMD_BUSUPGR;
    else if(~s1_req_wen)
      l2tag_req_cmd = `CMD_BUSRD;
    else
      l2tag_req_cmd = `CMD_BUSRDX;

  assign l2tag_snoop_valid = flush | fill;
  assign l2tag_snoop_tag = s1_snoop_tag_r;
  assign l2tag_snoop_addr = s1_snoop_addr_r;
  assign l2tag_snoop_way = flush ? tagmem_way_r : s1_req_fill_way_r;
  assign l2tag_snoop_wen = fill;
  assign l2tag_snoop_wdata = s1_snoop_data_r;

  // l2 interface
  assign l2tag_inv_valid = s1_snoop_valid_r & ~tagmiss &
                           ((s1_snoop_cmd_r == `CMD_BUSRDX) |
                            (s1_snoop_cmd_r == `CMD_BUSUPGR));
  assign l2tag_inv_addr = s1_snoop_addr_r;

  assign l2tag_idle = ~s0_req_valid_r & ~s1_req_valid_r;

  // bus interface
  assign l2_bus_hit = bus_hit_r;
  assign l2_bus_nack = bus_nack_r;

  // bus_hit_r
  always @(posedge clk)
    if(rst | (bus_cycle_r == 0))
      bus_hit_r <= 0;
    else if(s1_snoop_valid_r & ~tagmiss)
      bus_hit_r <= 1;

  // bus_nack_r
  always @(posedge clk)
    if(rst | (bus_cycle_r == 0))
      bus_nack_r <= 0;
    else if((flush & ~l2data_snoop_ready) |
            (l2tag_inv_valid & ~invfifo_ready) |
            pend_conflict | flush_conflict)
      bus_nack_r <= 1;

  // bus_cycle_r
  always @(posedge clk)
    if(rst)
      bus_cycle_r <= 0;
    else
      bus_cycle_r <= bus_cycle_r + 1;

  always @(posedge clk)
    if(rst)
      s0_req_beat_r <= 0;
    else if(s0_req_noop_beat)
      s0_req_beat_r <= s0_req_beat_r + 1;

  always @(posedge clk)
    if(rst)
      s0_req_valid_r <= 0;
    else if(~s0_req_stall) begin
      s0_req_valid_r <= req_valid;
      s0_req_noop_r <= s0_req_noop;
      s0_req_op_r <= req_op;
      s0_req_addr_r <= req_addr;
      s0_req_wmask_r <= req_wmask;
      s0_req_wdata_r <= req_wdata;
    end

  always @(posedge clk)
    if(rst)
      s0_snoop_valid_r <= 0;
    else begin
      s0_snoop_valid_r <= snoop_en & snoop_valid;
      if(snoop_en & snoop_valid) begin
        s0_snoop_cmd_r <= bus_cmd;
        s0_snoop_tag_r <= bus_tag;
        s0_snoop_addr_r <= bus_addr;
      end
    end

  always @(posedge clk)
    s0_snoop_data_r <= bus_data;

  always @(posedge clk)
    if(rst)
      s1_req_valid_r <= 0;
    else if(~s1_req_stall) begin
      s1_req_valid_r <= s0_req_valid_r & ~s0_snoop_valid_r;
      if(s0_req_valid_r & ~s0_snoop_valid_r) begin
        s1_req_noop_r <= s0_req_noop_r;
        s1_req_op_r <= s0_req_op_r;
        s1_req_addr_r <= s0_req_addr_r[31:3];
        s1_req_wmask_r <= s0_req_wmask_r;
        s1_req_wdata_r <= {2{s0_req_wdata_r}};
      end
    end

  always @(posedge clk)
    if(~s1_req_noop_r)
      if(s1_req_valid_r & ~s1_req_tag_stale_r) begin
        s1_req_tagmem_way_r <= (tagmiss & s1_req_overwrite) ? fill_way : tagmem_way_r;
        s1_req_tagmem_state_r <= tagmem_way_state;
        s1_req_tagmem_lru_r <= tagmem_lru_r;
        s1_req_fill_way_r <= fill_way;
        s1_req_fill_tag_r <= fill_tag;
      end else if(fill | (l2trans_valid & s1_req_evict_r)) begin
        s1_req_tagmem_way_r <= s1_req_fill_way_r;
        s1_req_tagmem_state_r <= s1_req_wen ? `STATE_M : `STATE_F;
      end

  always @(posedge clk) begin
    // reset state machine when we start processing a new request
    if(~s1_req_stall & ~s0_snoop_valid_r)
      s1_req_miss_r <= 0;

    // we have a fresh request, check for a miss and latch params
    if(s1_req_valid_r & ~s1_req_noop_r &
       ~s1_req_miss_r & ~s1_req_tag_stale_r) begin
      s1_req_miss_r <= tagmiss | upgr_shared;
      s1_req_upgr_r <= (~tagmiss & upgr_shared) | s1_req_overwrite;
      s1_req_evict_r <= evict;
    end

    // check confirmations from l2trans
    if(l2trans_valid)
      if(s1_req_evict_r)
        // we got the confirm for a Flush (eviction), now that we have an open
        // storage space, handle like a normal miss (issue a BusRd/BusRdX)
        s1_req_evict_r <= 0;
      else if(s1_req_upgr_r)
        // we got the confirmation for a BusUpgr, we're done
        s1_req_miss_r <= 0;
      else
        // we got the confirmation for a BusRd/BusRdX, do nothing
        ;

    // did we get the response to a BusRd/BusRdX?
    if(fill)
      s1_req_miss_r <= 0;
  end

  always @(posedge clk)
    s1_req_tag_stale_r <= s1_req_stall;

  always @(posedge clk)
    if(rst)
      s1_snoop_valid_r <= 0;
    else begin
      s1_snoop_valid_r <= s0_snoop_valid_r;
      if(s0_snoop_valid_r) begin
        s1_snoop_cmd_r <= s0_snoop_cmd_r;
        s1_snoop_tag_r <= s0_snoop_tag_r;
        s1_snoop_addr_r <= s0_snoop_addr_r;
      end
    end

  always @(posedge clk)
    s1_snoop_data_r <= s0_snoop_data_r;

  integer    i;
  reg [31:6] tmp_addr;
  reg [8:0]  tmp_set;
  reg [3:0]  tmp_way;
  always @(posedge clk) begin
    tmp_addr = s0_snoop_valid_r ? s0_snoop_addr_r : s0_req_addr_r[31:6];
    tmp_set = addr2set(tmp_addr);
    if(s0_snoop_valid_r | (s0_req_valid_r & ~s0_req_noop_r & ~s1_req_stall)) begin
      tmp_way = 0;
      for(i = 0; i < 4; i=i+1)
        if((tagmem_tag[tmp_set][i*17+:17] == addr2tag(tmp_addr)) &&
           (tagmem_state[tmp_set][i*3+:3] != `STATE_I))
          tmp_way = tmp_way | (1 << i);

      tagmem_way_r <= tmp_way;
      tagmem_states_r <= tagmem_state[tmp_set];
      tagmem_lru_r <= (lru_wset == tmp_set) ? lru_wdata : tagmem_lru[tmp_set];
      tagmem_tags_r <= tagmem_tag[tmp_set];
    end
  end

  reg       state_wen;
  reg [8:0] state_wset;
  reg [3:0] state_wway;
  reg [2:0] state_wdata;
  always @(*) begin
    state_wen = 0;
    state_wset = 0;
    state_wway = 0;
    state_wdata = 0;
    if(s1_snoop_valid_r) begin
      state_wset = addr2set(s1_snoop_addr_r);
      if(~tagmiss & (s1_snoop_cmd_r == `CMD_BUSRD)) begin
        // goto shared state on BusRd from other caches
        state_wen = 1;
        state_wway = tagmem_way_r;
        state_wdata = `STATE_S;
      end else if(~tagmiss &
                  (s1_snoop_cmd_r == `CMD_BUSRDX ||
                   s1_snoop_cmd_r == `CMD_BUSUPGR) &
                  invfifo_ready) begin
        // invalidate on BusRdX from other caches
        state_wen = 1;
        state_wway = tagmem_way_r;
        state_wdata = `STATE_I;
      end else if(pend_valid_r & pend_tag_valid_r &
                  (s1_snoop_tag_r == {BUSID,pend_tag_r})) begin
        // goto forward state on completed BusRd (TODO: exclusive state)
        // goto modified state on completed BusRdX
        state_wen = 1;
        state_wway = s1_req_fill_way_r;
        state_wdata = s1_req_wen ? `STATE_M : `STATE_F;
      end
    end else if(s1_req_valid_r & ~s1_req_noop_r & s1_req_wen & ~s1_req_stall) begin
      // goto modified state from exclusive state
      state_wset = addr2set(s1_req_addr_r[31:6]);
      if(s1_req_tag_stale_r) begin
        state_wen = s1_req_tagmem_state_r == `STATE_E;
        state_wway = s1_req_tagmem_way_r;
      end else begin
        state_wen = tagmem_way_state == `STATE_E;
        state_wway = tagmem_way_r;
      end
      state_wdata = `STATE_M;
    end else if(l2trans_valid & (pend_cmd_r == `CMD_BUSUPGR)) begin
      // goto modified state on completed BusUpgr
      state_wen = 1;
      state_wset = addr2set(s1_req_addr_r[31:6]);
      state_wway = s1_req_tagmem_way_r;
      state_wdata = `STATE_M;
    end
  end

  integer k;
  always @(posedge clk)
    if(rst)
      for(k = 0; k < 512; k=k+1)
        tagmem_state[k] <= 0;
    else if(state_wen)
      tagmem_state[state_wset][oh2idx(state_wway)*3+:3] <= state_wdata;

  reg        tag_wen;
  reg [8:0]  tag_wset;
  reg [3:0]  tag_wway;
  reg [16:0] tag_wdata;
  always @(*) begin
    tag_wen = 0;
    tag_wset = 0;
    tag_wway = 0;
    tag_wdata = 0;
    if(fill) begin
      tag_wen = 1;
      tag_wset = addr2set(s1_snoop_addr_r);
      tag_wway = s1_req_fill_way_r;
      tag_wdata = addr2tag(s1_snoop_addr_r);
    end else if(s1_req_valid_r & s1_req_overwrite & l2trans_valid) begin
      tag_wen = 1;
      tag_wset = addr2set(s1_req_addr_r[31:6]);
      tag_wway = s1_req_tagmem_way_r;
      tag_wdata = addr2tag(s1_req_addr_r[31:6]);
    end
  end

  always @(posedge clk)
    if(tag_wen)
      tagmem_tag[tag_wset][oh2idx(tag_wway)*17+:17] <= tag_wdata;

  always @(posedge clk)
    if(lru_wen)
      tagmem_lru[lru_wset] <= lru_wdata;

  always @(posedge clk)
    if(rst)
      pend_valid_r <= 0;
    else begin
      // are we scheduling a new command?
      if(l2tag_req_valid & l2data_req_ready & l2tag_req_cmd_valid) begin
        pend_valid_r <= 1;
        pend_cmd_r <= l2tag_req_cmd;
        pend_tag_valid_r <= 0;
      end

      // did a BusUpgr get upgraded to a BusRdX?
      if(l2trans_upgr_hit)
        pend_cmd_r <= `CMD_BUSRDX;

      // l2trans lets us know when our scheduled command was sent
      if(l2trans_valid)
        case(pend_cmd_r)
          `CMD_BUSRD, `CMD_BUSRDX: begin
            // grab tag and wait for the Fill/Flush
            pend_tag_valid_r <= 1;
            pend_tag_r <= l2trans_tag;
          end
          `CMD_BUSUPGR:
            // all done, tagmem will change state to M
            pend_valid_r <= 0;
          `CMD_FLUSH:
            // all done, will follow up with BusRd/BusRdX as appropriate
            pend_valid_r <= 0;
        endcase

      // did we get the response to a BusRd/BusRdX?
      if(fill)
        pend_valid_r <= 0;
    end

endmodule
