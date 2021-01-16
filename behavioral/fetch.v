// instruction fetch unit
module fetch(
  input         clk,
  input         rst,

  // icache interface
  output        fetch_ic_req,
  output [31:2] fetch_ic_addr,
  output        fetch_ic_flush,
  input         icache_ready,
  input         icache_valid,
  input         icache_error,
  input [31:0]  icache_data,

  // brpred interface
  output        fetch_bp_req,
  output [31:2] fetch_bp_addr,
  input [15:0]  brpred_bptag,
  input         brpred_bptaken,

  // decode interface
  output        fetch_de_valid,
  output        fetch_de_error,
  output [31:1] fetch_de_addr,
  output [31:0] fetch_de_insn,
  output [15:0] fetch_de_bptag,
  output        fetch_de_bptaken,
  input         decode_stall,

  // rob interface
  input         rob_flush,
  input [31:2]  rob_flush_pc);

  reg [31:1] pc;

  reg [15:0] buf_valid;
  reg [15:0] buf_error;
  reg [31:1] buf_addr [0:15];
  reg [31:0] buf_insn [0:15];
  reg [15:0] buf_bptag [0:15];
  reg [15:0] buf_bptaken;

  // buf_tail advanced upon issuing icache requests
  // buf_mid advanced upon receiving icache responses
  // buf_head advanced upon sending insns to decode
  // *_pol used to distinguish between empty and full conditions
  reg [3:0]  buf_head, buf_mid, buf_tail;
  reg        buf_head_pol, buf_mid_pol, buf_tail_pol;

  reg        bp_req_r;
  reg        insn_jal_r;
  reg        jalr_halt_r;
  reg        misalign_err_r;

  // br/jal target computation
  function [31:1] br_target(
    input [31:2] base,
    input [31:0] insn);
    br_target = $signed({base,1'b0}) + $signed({insn[31],insn[7],insn[30:25],insn[11:8]});
  endfunction

  function [31:1] jal_target(
    input [31:2] base,
    input [31:0] insn);
    jal_target = $signed({base,1'b0}) + $signed({insn[31],insn[19:12],insn[20],insn[30:21]});
  endfunction

  // derived signals
  wire buf_empty, buf_full;
  assign buf_empty = (buf_head == buf_tail) & (buf_head_pol == buf_tail_pol);
  assign buf_full  = (buf_head == buf_tail) & (buf_head_pol != buf_tail_pol);

  wire icache_beat;
  assign icache_beat = fetch_ic_req & icache_ready;

  wire decode_beat;
  assign decode_beat = fetch_de_valid & ~decode_stall;

  wire insn_br, insn_jal, insn_jalr;
  assign insn_br   = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1100011);
  assign insn_jal  = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1101111);
  assign insn_jalr = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1100111);

  wire br_taken;
  assign br_taken = bp_req_r & brpred_bptaken;

  wire setpc;
  assign setpc = rob_flush | br_taken | insn_jal_r;

  wire pc_misaligned;
  assign pc_misaligned = pc[1];

  wire gen_misalign_err;
  assign gen_misalign_err = pc_misaligned & ~misalign_err_r & ~buf_full & ~setpc;

  // fetch interface
  assign fetch_ic_req = ~buf_full & ~fetch_ic_flush & ~jalr_halt_r & ~pc_misaligned;
  assign fetch_ic_addr = pc[31:2];
  assign fetch_ic_flush = setpc | insn_jalr;

  // brpred interface
  assign fetch_bp_req = insn_br;
  assign fetch_bp_addr = buf_addr[buf_mid][31:2];

  // decode interface
  assign fetch_de_valid = ~buf_empty & buf_valid[buf_head];
  assign fetch_de_error = buf_error[buf_head];
  assign fetch_de_addr = buf_addr[buf_head];
  assign fetch_de_insn = buf_insn[buf_head];
  assign fetch_de_bptag = buf_bptag[buf_head];
  assign fetch_de_bptaken = buf_bptaken[buf_head];

  // pc
  always @(posedge clk)
    if(rst)
      pc <= 0;
    else if(rob_flush)
      pc <= {rob_flush_pc,1'b0};
    else if(br_taken)
      pc <= br_target(buf_addr[buf_mid-1][31:2], buf_insn[buf_mid-1]);
    else if(insn_jal_r)
      pc <= jal_target(buf_addr[buf_mid-1][31:2], buf_insn[buf_mid-1]);
    else if(icache_beat)
      pc <= pc + 2;

  // buf_tail
  always @(posedge clk)
    if(rst | rob_flush) begin
      buf_tail <= 0;
      buf_tail_pol <= 0;
    end else if(fetch_ic_flush) begin
      buf_tail <= buf_mid;
      buf_tail_pol <= buf_mid_pol;
    end else if(icache_beat)
      {buf_tail_pol,buf_tail} <= {buf_tail_pol,buf_tail} + 1;

  // buf_mid
  always @(posedge clk)
    if(rst | rob_flush) begin
      buf_mid <= 0;
      buf_mid_pol <= 0;
    end else if(icache_valid)
      {buf_mid_pol,buf_mid} <= {buf_mid_pol,buf_mid} + 1;

  // buf_head
  always @(posedge clk)
    if(rst | rob_flush) begin
      buf_head <= 0;
      buf_head_pol <= 0;
    end else if(decode_beat)
      {buf_head_pol,buf_head} <= {buf_head_pol,buf_head} + 1;

  // buf
  always @(posedge clk)
    if(rst)
      buf_valid <= 0;
    else begin
      if(gen_misalign_err) begin
        buf_valid[buf_tail] <= 1;
        buf_error[buf_tail] <= 1;
        buf_addr[buf_tail] <= pc;
      end

      if(icache_beat) begin
        buf_valid[buf_tail] <= 0;
        buf_addr[buf_tail] <= pc;
      end

      if(icache_valid) begin
        if(~fetch_bp_req)
          buf_valid[buf_mid] <= 1;
        buf_error[buf_mid] <= icache_error;
        buf_insn[buf_mid] <= icache_data;
      end

      if(bp_req_r) begin
        buf_valid[buf_mid-1] <= 1;
        buf_bptag[buf_mid-1] <= brpred_bptag;
        buf_bptaken[buf_mid-1] <= brpred_bptaken;
      end
    end

  // bp_req_r
  always @(posedge clk)
    if(rst)
      bp_req_r <= 0;
    else
      bp_req_r <= fetch_bp_req;

  // insn_jal_r
  always @(posedge clk)
    if(rst)
      insn_jal_r <= 0;
    else
      insn_jal_r <= insn_jal;

  // jalr_halt_r
  always @(posedge clk)
    if(rst | setpc)
      jalr_halt_r <= 0;
    else if(insn_jalr)
      jalr_halt_r <= 1;

  // misalign_err_r
  always @(posedge clk)
    if(rst | setpc)
      misalign_err_r <= 0;
    else if(gen_misalign_err)
      misalign_err_r <= 1;

endmodule
