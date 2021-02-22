// data cache
module dcache(
  input         clk,
  input         rst,

  // lsq interface
  input         lsq_dc_req,
  input [3:0]   lsq_dc_op,
  input [31:0]  lsq_dc_addr,
  input [3:0]   lsq_dc_lsqid,
  input [31:0]  lsq_dc_wdata,
  input         lsq_dc_flush,
  output        dcache_lsq_ready,
  output        dcache_lsq_valid,
  output        dcache_lsq_error,
  output [3:0]  dcache_lsq_lsqid,
  output [31:0] dcache_lsq_rdata,

  // l2 interface
  output        dcache_l2fifo_req,
  output [31:2] dcache_l2fifo_addr,
  output        dcache_l2fifo_wen,
  output [3:0]  dcache_l2fifo_wmask,
  output [31:0] dcache_l2fifo_wdata,
  input         l2fifo_dc_ready,

  input         l2_resp_valid,
  input         l2_resp_error,
  input [63:0]  l2_resp_rdata,
  output        resp_ready,

  input         l2_inv_valid,
  input [31:6]  l2_inv_addr,
  output        inv_ready);

  // 32KB, 4-way associative, 64B line => 128 sets
  function automatic [6:0] addr2set(
    input [31:2] addr);

    addr2set = addr[12:6];
  endfunction

  function automatic [18:0] addr2tag(
    input [31:2] addr);

    addr2tag = addr[31:13];
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

  // 4 valid bits, 3 lru bits, 19*4 tag bits
  reg [3:0]  tagmem_valid [0:127];
  reg [2:0]  tagmem_lru [0:127];
  reg [75:0] tagmem_tag [0:127];

  // 8B wide, 32KB, 64B line => 4096 entries
  reg [63:0] datamem [0:4095];

  // 1 MSHR
  reg        mshr_valid;
  reg        mshr_obsolete;
  reg [31:6] mshr_addr;
  reg [3:0]  mshr_way;
  reg [15:0] mshr_req_valid;
  reg [31:0] mshr_req_offset;
  reg [47:0] mshr_req_op;
  reg [63:0] mshr_req_lsqid;
  reg        mshr_wen;
  reg [63:0] mshr_wmask;

  // read buffer
  // latches response data from l2
  reg        rbuf_started;
  reg [7:0]  rbuf_valid;
  reg [7:0]  rbuf_filled;
  reg [3:0]  rbuf_head;
  reg [3:0]  rbuf_tail;
  reg [63:0] rbuf_data [0:7];

  // stage 0 latches
  reg        s0_req_r;
  reg        s0_inv_r;
  reg [3:0]  s0_op_r;
  reg [31:0] s0_addr_r;
  reg [3:0]  s0_lsqid_r;
  reg [31:0] s0_wdata_r;

  // cycle counter for burst transactions (lbcmp)
  reg [1:0]  s0_cycle_r;

  // stage 0 signals
  reg        s0_stall;

  // s0_addr_r fields
  reg [18:0] s0_tag;
  reg [6:0]  s0_set;

  // values read from tagmem
  reg [3:0]  s0_tagmem_valid;
  reg [2:0]  s0_tagmem_lru;
  reg [18:0] s0_tagmem_tag [0:3];

  // tag comparison results
  reg [3:0]  s0_taghits;
  reg        s0_tagmiss;
  reg        s0_mshrhit;
  reg        s0_rd_forward;
  reg        s0_rd_merge;
  reg        s0_wr_merge;
  wire       s0_mshr_alloc;
  wire       s0_invalid_way_avail;
  wire [3:0] s0_invalid_way_sel;
  reg [3:0]  s0_mshr_alloc_way;

  // pma checker
  wire       pma_valid;

  // decoded from wdata and op (sw/sh/sb)
  reg [3:0]  s0_wmask;
  reg [31:0] s0_wdata_aligned;

  // beat transaction signals (lbcmp)
  wire [2:0] s0_op;
  wire       s0_burst;
  wire       s0_last;
  wire       s0_burst_beat;

  // stage 1 latches
  // datamem read port
  reg        s1_req_r;
  reg [11:0] s1_raddr_r;

  // datamem write port
  reg        s1_wen_r;
  reg [11:0] s1_waddr_r;
  reg [7:0]  s1_wmask_r;
  reg [63:0] s1_wdata_r;

  // forwarding (resp data from rbuf rather than datamem)
  reg        s1_forward_r;
  reg        s1_error_r;
  reg [3:1]  s1_op_r;
  reg [3:0]  s1_lsqid_r;
  reg [2:0]  s1_offset_r;
  reg [7:0]  s1_op2_r;

  // stage 1 signals
  wire       s1_stall;

  // fill signals (moves data from rbuf to datamem)
  reg        fill_wen;
  reg        fill_done;
  reg [11:0] fill_index;
  reg [63:0] fill_data;

  // stage 2 latches
  // four possible inputs, in priority order:
  // 1. forwarding directly from l2_rdata (lower 32 bits)
  // 2. forwarding directly from l2_rdata (upper 32 bits)
  // 3. forwarding from rbuf (s1_forward_r)
  // 4. datamem read (s1_req_r)
  reg        s2_req_r;
  reg        s2_error_r;
  reg [3:1]  s2_op_r;
  reg [3:0]  s2_lsqid_r;
  reg [2:0]  s2_offset_r;
  reg [7:0]  s2_op2_r;
  reg [63:0] s2_rdata_r;

  // shift register holding intermediate results during lbcmp (burst)
  reg [23:0] s2_bcmp_r;

  // stage 2 signals
  wire       s2_burst;
  wire       s2_last;

  reg [7:0]  s2_bcmp_result;

  // encoded from rdata and op (lw/lh/lb/lhu/lbu)
  reg [31:0] s2_rdata_muxed;
  reg [31:0] s2_rdata_aligned;
  reg [31:0] s2_rdata_extended;

  // derived signals
  wire l2_req_beat;
  assign l2_req_beat = dcache_l2fifo_req & l2fifo_dc_ready;

  wire l2_resp_beat;
  assign l2_resp_beat = l2_resp_valid & resp_ready;

  // mshr_req_* fields are shifted right by 2 on each l2_resp_beat
  wire [1:0] l2req_fwd_valid;
  assign l2req_fwd_valid = mshr_obsolete ? 0 : mshr_req_valid[1:0];

  // must stall when there is a higher priority input to stage 2 present
  assign s1_stall = (s1_req_r | s1_forward_r) & l2_resp_valid & (|l2req_fwd_valid);

  // lsq interface
  assign dcache_lsq_ready = ~s0_stall & ~l2_inv_valid;
  assign dcache_lsq_valid = s2_req_r & s2_last & ~lsq_dc_flush;
  assign dcache_lsq_error = s2_error_r;
  assign dcache_lsq_lsqid = s2_lsqid_r;
  assign dcache_lsq_rdata = s2_burst ? {s2_bcmp_result,s2_bcmp_r} : s2_rdata_extended;

  // l2 interface
  assign dcache_l2fifo_req = s0_req_r & ~s0_inv_r & pma_valid &
                             ((~s0_op_r[0] & s0_tagmiss & ~mshr_valid) |
                              (s0_op_r[0] & (~s0_mshrhit | s0_wr_merge)));
  assign dcache_l2fifo_addr = ~s0_op_r[0] ? {s0_addr_r[31:6],4'b0} : s0_addr_r[31:2];
  assign dcache_l2fifo_wen = s0_op_r[0];
  assign dcache_l2fifo_wmask = s0_wmask;
  assign dcache_l2fifo_wdata = s0_wdata_aligned;

  assign resp_ready = ~&l2req_fwd_valid;
  assign inv_ready = ~s0_stall;

  // s0 input latches
  always @(posedge clk)
    if(rst | (lsq_dc_flush & ~s0_op_r[0]))
      s0_req_r <= 0;
    else if(~s0_stall) begin
      s0_req_r <= lsq_dc_req | l2_inv_valid;
      s0_inv_r <= l2_inv_valid;
      if(l2_inv_valid) begin
        // inhibit s0_rd_forward/s0_rd_merge/s0_mshr_alloc
        // s0_wr_merge/s0_wen checks s0_req_r explicitly
        s0_op_r <= 1;
        s0_addr_r <= {l2_inv_addr,6'b0};
      end else if(lsq_dc_req) begin
        s0_op_r <= lsq_dc_op;
        s0_addr_r <= lsq_dc_addr;
        s0_lsqid_r <= lsq_dc_lsqid;
        s0_wdata_r <= lsq_dc_wdata;
      end
    end else if(s0_burst_beat)
      s0_addr_r <= s0_addr_r + 8;

  // tagmem read and compare
  integer i;
  always @(*) begin
    s0_tag = addr2tag(s0_addr_r[31:2]);
    s0_set = addr2set(s0_addr_r[31:2]);

    s0_tagmem_valid = tagmem_valid[s0_set];
    s0_tagmem_lru = tagmem_lru[s0_set];
    for(i = 0; i < 4; i=i+1) begin
      s0_tagmem_tag[i] = tagmem_tag[s0_set][i*19+:19];
      s0_taghits[i] = s0_tagmem_valid[i] & (s0_tagmem_tag[i] == s0_tag);
    end
    s0_tagmiss = ~|s0_taghits;
  end

  // s0_rd_forward, s0_rd_merge, s0_wr_merge
  //
  // reads
  // mshrmiss: 0, tagmiss: x => stall if mshr_valid & (mshr_wen | (~rbuf_valid[i] & (rbuf_started | mshr_req_valid[i] | mshr_obsolete)))
  //                            forward from rbuf if mshr_valid & rbuf_valid[i]
  //                            merge into mshr otherwise
  // mshrmiss: 1, tagmiss: 0 => read datamem
  // mshrmiss: 1, tagmiss: 1 => stall if mshr_valid
  //                            write mshr otherwise
  //
  // writes
  // mshrmiss: 0, tagmiss: x => send to L2
  //                            stall if mshr_valid & rbuf_filled[i]
  //                            merge into mshr/datamem if mshr_valid
  // mshrmiss: 1, tagmiss: 0 => send to L2
  //                            write into datamem
  // mshrmiss: 1, tagmiss: 1 => send to L2
  always @(*) begin
    s0_mshrhit = mshr_valid & (mshr_addr == s0_addr_r[31:6]);

    // Can we forward read data, or merge a read?
    s0_rd_merge = 0;
    s0_rd_forward = 0;
    // check mshr_wen since we can't forward/merge the read if there is pending wdata
    if(~s0_op_r[0] & s0_mshrhit & ~mshr_wen)
      // is there pending rdata in the rbuf for this addr?
      if(rbuf_valid[s0_addr_r[5:3]])
        // forward the data from the rbuf
        s0_rd_forward = 1;
      else
        // merge into the mshr if the slot is free and there hasn't been a flush
        s0_rd_merge = ~l2_resp_valid & ~rbuf_started & ~mshr_req_valid[s0_addr_r[5:2]] &
                      ~mshr_obsolete & ~s0_burst;

    // can we merge a write?
    s0_wr_merge = ~s0_inv_r & s0_op_r[0] & s0_mshrhit & ~rbuf_filled[s0_addr_r[5:3]];
  end

  assign s0_mshr_alloc = s0_req_r & ~s0_op_r[0] & pma_valid & s0_tagmiss
                         & l2fifo_dc_ready & ~mshr_valid;

  // invalid_way_*
  priarb #(4) invalid_way_arb(
    .req(~s0_tagmem_valid),
    .grant_valid(s0_invalid_way_avail),
    .grant(s0_invalid_way_sel));

  // s0_mshr_alloc_way
  always @(*)
    // if there are any invalid ways, use those instead of lru bits
    if(s0_invalid_way_avail)
       s0_mshr_alloc_way = s0_invalid_way_sel;
    else
      // compute lru way
      casez(s0_tagmem_lru)
        3'b0?0: s0_mshr_alloc_way[0] = 1;
        3'b0?1: s0_mshr_alloc_way[1] = 1;
        3'b10?: s0_mshr_alloc_way[2] = 1;
        3'b11?: s0_mshr_alloc_way[3] = 1;
      endcase

  // s0_stall
  always @(*) begin
    s0_stall = 0;
    if(s0_req_r)
      if(s0_burst & ~s0_last)
        s0_stall = pma_valid;
      else if(s0_inv_r)
        s0_stall = s0_mshrhit;
      else if(~s0_op_r[0])
        if(s0_mshrhit)
          s0_stall = (~s0_rd_forward | s1_stall) & ~s0_rd_merge;
        else if(s0_tagmiss)
          s0_stall = pma_valid & (~l2fifo_dc_ready | mshr_valid);
        else
          s0_stall = s1_stall;
      else
        s0_stall = ~l2fifo_dc_ready | (s0_mshrhit & ~s0_wr_merge);
  end

  assign s0_op = s0_burst ? {s0_last,2'b11} : s0_op_r[3:1];

  wire s0_wen;
  assign s0_wen = s0_req_r & ~s0_inv_r & s0_op_r[0] &
                  (~s0_tagmiss | (s0_mshrhit & ~rbuf_filled[s0_addr_r[5:3]])) &
                  l2fifo_dc_ready;

  pmacheck pmacheck(
    .addr(s0_addr_r[31:6]),
    .write(s0_op_r[0]),
    .valid(pma_valid));

  // s0_wmask, s0_wdata
  // TODO handle misalignment
  always @(*)
    case(s0_op_r[2:1])
      2'b00: begin // SB
        s0_wmask = 4'b0001 << s0_addr_r[1:0];
        s0_wdata_aligned = {4{s0_wdata_r[7:0]}};
      end
      2'b01: begin // SH
        s0_wmask = 4'b0011 << (s0_addr_r[1] * 2);
        s0_wdata_aligned = {2{s0_wdata_r[15:0]}};
      end
      default: begin // SW
        s0_wmask = 4'b1111;
        s0_wdata_aligned = s0_wdata_r;
      end
    endcase

  // beat transaction signals
  assign s0_burst = (s0_op_r[2:0] == 3'b110);
  assign s0_last = ~s0_burst | (&s0_cycle_r);
  assign s0_burst_beat = s0_req_r & s0_burst & pma_valid &
                         (s0_rd_forward | (~s0_mshrhit & ~s0_tagmiss)) &
                         ~s1_stall;

  // s0_cycle_r
  always @(posedge clk)
    if(rst)
      s0_cycle_r <= 0;
    else if(s0_burst_beat)
      s0_cycle_r <= s0_cycle_r + 1;

  // s1 input latches
  always @(posedge clk)
    if(rst) begin
      s1_req_r <= 0;
      s1_wen_r <= 0;
    end else if(~s1_stall) begin
      s1_req_r <= s0_req_r & ~s0_op_r[0] & ~s0_mshrhit & ~s0_tagmiss & ~lsq_dc_flush;
      s1_forward_r <= s0_req_r & ~s0_inv_r & (s0_rd_forward | ~pma_valid) & ~lsq_dc_flush;
      s1_error_r <= ~pma_valid;
      s1_offset_r <= s0_addr_r[2:0];
      s1_op_r <= s0_op;
      s1_lsqid_r <= s0_lsqid_r;
      s1_raddr_r <= {s0_set,oh2idx(s0_taghits),s0_addr_r[5:3]};
      s1_op2_r <= s0_wdata_r[7:0];
    end

  always @(posedge clk)
    if(s0_wen) begin
      s1_wen_r <= 1;
      s1_waddr_r <= {s0_set,
        s0_mshrhit ? oh2idx(mshr_way) : oh2idx(s0_taghits),
        s0_addr_r[5:3]};
      s1_wmask_r <= {4'b0,s0_wmask} << (s0_addr_r[2] * 4);
      s1_wdata_r <= {4{s0_wdata_aligned}};
    end else if(fill_wen) begin
      s1_wen_r <= 1;
      s1_waddr_r <= fill_index;
      s1_wmask_r <= ~mshr_wmask[rbuf_head[2:0]*8+:8];
      s1_wdata_r <= fill_data;
    end else
      s1_wen_r <= 0;

  // fill_*
  always @(*) begin
    fill_wen = rbuf_head != rbuf_tail;
    fill_done = fill_wen & (&rbuf_head[2:0]);
    fill_index = {addr2set({mshr_addr,4'b0}),oh2idx(mshr_way),rbuf_head[2:0]};

    fill_data = rbuf_data[rbuf_head[2:0]];
  end

  // s2 input latches
  always @(posedge clk)
    if(rst | lsq_dc_flush)
      s2_req_r <= 0;
    else begin
      if(l2_resp_valid & l2req_fwd_valid[0]) begin
        s2_req_r <= 1;
        s2_error_r <= 0;
        s2_offset_r <= {1'b0,mshr_req_offset[1:0]};
        s2_lsqid_r <= mshr_req_lsqid[3:0];
        s2_op_r <= mshr_req_op[2:0];
        s2_rdata_r <= l2_resp_rdata;
      end else if(l2_resp_valid & l2req_fwd_valid[1]) begin
        s2_req_r <= 1;
        s2_error_r <= 0;
        s2_offset_r <= {1'b1,mshr_req_offset[3:2]};
        s2_lsqid_r <= mshr_req_lsqid[7:4];
        s2_op_r <= mshr_req_op[5:3];
        s2_rdata_r <= l2_resp_rdata;
      end else if(s1_forward_r | s1_req_r) begin
        s2_req_r <= 1;
        s2_error_r <= s1_error_r;
        s2_offset_r <= s1_offset_r;
        s2_lsqid_r <= s1_lsqid_r;
        s2_op_r <= s1_op_r;
        s2_op2_r <= s1_op2_r;
        s2_rdata_r <= s1_forward_r ? rbuf_data[s1_raddr_r[2:0]] : datamem[s1_raddr_r];
      end else
        s2_req_r <= 0;
    end

  // s2_bcmp_r
  always @(posedge clk)
    if(s2_req_r & s2_burst)
      s2_bcmp_r <= {s2_bcmp_result,s2_bcmp_r[23:8]};

  assign s2_burst = &s2_op_r[2:1];
  assign s2_last = ~s2_burst | s2_op_r[3];

  // s2_bcmp_result
  integer l;
  always @(*)
    for(l = 0; l < 8; l=l+1)
      s2_bcmp_result[l] = s2_rdata_r[l*8+:8] == s2_op2_r;

  // s2_rdata_*
  always @(*) begin
    s2_rdata_muxed = s2_rdata_r[s2_offset_r[2]*32+:32];
    s2_rdata_aligned = s2_rdata_muxed >> (s2_offset_r[1:0] * 8);
    casez(s2_op_r)
      3'b000: // LB
        s2_rdata_extended = $signed(s2_rdata_aligned[7:0]);
      3'b001: // LH
        s2_rdata_extended = $signed(s2_rdata_aligned[15:0]);
      3'b01?: // LW
        s2_rdata_extended = s2_rdata_aligned;
      3'b1?0: // LBU
        s2_rdata_extended = s2_rdata_aligned[7:0];
      3'b1?1: // LHU
        s2_rdata_extended = s2_rdata_aligned[15:0];
    endcase
  end

  // tagmem write
  integer j;
  always @(posedge clk)
    if(rst)
      for(j = 0; j < 128; j=j+1) begin
        tagmem_valid[j] <= 0;
        tagmem_lru[j] <= 0;
      end
    else begin
      // valid bits
      if(fill_done)
        tagmem_valid[addr2set({mshr_addr,4'b0})][oh2idx(mshr_way)] <= 1;
      else if(~s0_wen & fill_wen)
        tagmem_valid[addr2set({mshr_addr,4'b0})][oh2idx(mshr_way)] <= 0;
      else if(s0_req_r & s0_inv_r & ~s0_mshrhit & ~s0_tagmiss)
        tagmem_valid[addr2set(s0_addr_r[31:2])][oh2idx(s0_taghits)] <= 0;

      // lru bits
      if(s0_req_r & ~s0_inv_r & ~s0_mshrhit) begin
        if(~s0_tagmiss)
          tagmem_lru[s0_set] <= next_lru(s0_taghits, tagmem_lru[s0_set]);
        else if(s0_mshr_alloc)
          tagmem_lru[s0_set] <= next_lru(s0_mshr_alloc_way, tagmem_lru[s0_set]);
      end

      // tag bits
      if(fill_done)
        tagmem_tag[addr2set({mshr_addr,4'b0})][oh2idx(mshr_way)*19+:19] <= addr2tag({mshr_addr,4'b0});
    end

  // datamem write
  integer k;
  always @(posedge clk)
    if(s1_wen_r)
      for(k = 0; k < 8; k=k+1)
        if(s1_wmask_r[k])
          datamem[s1_waddr_r][k*8+:8] <= s1_wdata_r[k*8+:8];

  // mshr write
  always @(posedge clk)
    if(rst)
      mshr_valid <= 0;
    else begin
      if(s0_mshr_alloc) begin
        mshr_valid <= 1;
        mshr_obsolete <= 0;
        mshr_addr <= s0_addr_r[31:6];
        mshr_way <= s0_mshr_alloc_way;
        mshr_req_valid <= ~s0_burst ? (1 << s0_addr_r[5:2]) : 0;
        mshr_req_offset[s0_addr_r[5:2]*2+:2] <= s0_addr_r[1:0];
        mshr_req_op[s0_addr_r[5:2]*3+:3] <= s0_op_r[3:1];
        mshr_req_lsqid[s0_addr_r[5:2]*4+:4] <= s0_lsqid_r;
        mshr_wen <= 0;
        mshr_wmask <= 0;
      end

      if(s0_req_r & s0_rd_merge) begin
        mshr_req_valid[s0_addr_r[5:2]] <= 1;
        mshr_req_offset[s0_addr_r[5:2]*2+:2] <= s0_addr_r[1:0];
        mshr_req_op[s0_addr_r[5:2]*3+:3] <= s0_op_r[3:1];
        mshr_req_lsqid[s0_addr_r[5:2]*4+:4] <= s0_lsqid_r;
      end

      if(s0_req_r & s0_wr_merge) begin
        mshr_wen <= 1;
        mshr_wmask[s0_addr_r[5:2]*4+:4] <= mshr_wmask[s0_addr_r[5:2]*4+:4] | s0_wmask;
      end

      if(l2_resp_valid) begin
        if(resp_ready) begin
          mshr_req_valid <= {2'b0,mshr_req_valid[15:2]};
          mshr_req_offset <= {4'b0,mshr_req_offset[31:4]};
          mshr_req_op <= {6'b0,mshr_req_op[47:6]};
          mshr_req_lsqid <= {8'b0,mshr_req_lsqid[63:8]};
        end else
          mshr_req_valid[0] <= 0;
      end

      if(fill_done)
        mshr_valid <= 0;

      if(lsq_dc_flush)
        mshr_obsolete <= 1;
    end

  // rbuf write
  always @(posedge clk)
    if(rst) begin
      rbuf_head <= 0;
      rbuf_tail <= 0;
      rbuf_valid <= 0;
      rbuf_filled <= 0;
    end else begin
      if(s0_mshr_alloc) begin
        rbuf_started <= 0;
        rbuf_valid <= 0;
        rbuf_filled <= 0;
      end

      if(l2_resp_beat) begin
        rbuf_started <= 1;
        rbuf_tail <= rbuf_tail + 1;
        rbuf_valid <= {rbuf_valid[6:0],1'b1};
        rbuf_data[rbuf_tail[2:0]] <= l2_resp_rdata;
      end

      if(~s0_wen & fill_wen) begin
        rbuf_head <= rbuf_head + 1;
        rbuf_filled <= {rbuf_filled[6:0],1'b1};
      end
    end

  // testbench callbacks
  always @(posedge clk) begin
    if(lsq_dc_req & dcache_lsq_ready)
      top.log_dcache_req(
        lsq_dc_lsqid,
        lsq_dc_op,
        lsq_dc_addr,
        lsq_dc_wdata);
    if(dcache_lsq_valid)
      top.log_dcache_resp(
        dcache_lsq_lsqid,
        dcache_lsq_error,
        dcache_lsq_rdata);
  end

endmodule
