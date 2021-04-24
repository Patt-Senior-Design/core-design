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

  wire [31:1] pc;

  wire [15:0] buf_valid;
  wire [15:0] buf_error;
  wire [(31*16)-1:0] buf_addr;
  wire [(32*16)-1:0] buf_insn;
  wire [15:0] buf_bptaken;
  wire [(16*16)-1:0] buf_bptag;

  // buf_tail advanced upon issuing icache requests
  // buf_mid advanced upon receiving icache responses
  // buf_head advanced upon sending insns to decode
  // *_pol used to distinguish between empty and full conditions
  wire [15:0] buf_head_oh, buf_mid_oh, buf_tail_oh;
  wire [3:0]  buf_head, buf_tail, buf_mid;
  wire        buf_head_pol, buf_tail_pol, buf_mid_pol;

  wire        bp_req_r;
  wire        insn_jal_r;
  wire        jalr_halt_r;
  wire        misalign_err_r;

  /*verilator lint_off WIDTH*/
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
  /*verilator lint_on WIDTH*/

  // derived signals
  wire buf_empty, buf_full;
  //assign buf_empty = (buf_head_oh == buf_tail_oh) & (buf_head_pol == buf_tail_pol);
  //assign buf_full  = (buf_head_oh == buf_tail_oh) & (buf_head_pol != buf_tail_pol);
  assign buf_empty = (buf_head == buf_tail) & (buf_head_pol == buf_tail_pol);
  assign buf_full  = (buf_head == buf_tail) & (buf_head_pol != buf_tail_pol);

  wire [3:0] buf_mid_prev;
  wire [15:0] buf_mid_prev_oh = {buf_mid_oh[0], buf_mid_oh[15:1]};
  // debugging
  encoder #(16) mid_prev_enc (.in(buf_mid_prev_oh), .invalid(), .out(buf_mid_prev));  

  wire icache_beat = fetch_ic_req & icache_ready;
  wire decode_beat = fetch_de_valid & ~decode_stall;

  wire insn_br, insn_jal, insn_jalr;
  assign insn_br   = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1100011);
  assign insn_jal  = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1101111);
  assign insn_jalr = icache_valid & ~icache_error & (icache_data[6:0] == 7'b1100111);

  wire br_taken = bp_req_r & brpred_bptaken;

  wire setpc = rob_flush | br_taken | insn_jal_r;

  wire pc_misaligned = pc[1];

  wire gen_misalign_err = pc_misaligned & ~misalign_err_r & ~buf_full & ~setpc;

  // fetch interface
  assign fetch_ic_req = ~buf_full & ~fetch_ic_flush & ~jalr_halt_r & ~pc_misaligned;
  assign fetch_ic_addr = pc[31:2];
  assign fetch_ic_flush = setpc | insn_jalr;

  // buf read ports
  //
  // buf valid
  wire buf_valid_head;
  premux #(1, 16) buf_valid_head_mux (.sel(buf_head_oh), .in(buf_valid), .out(buf_valid_head));
  // buf error
  wire buf_error_head;
  premux #(1, 16) buf_error_head_mux (.sel(buf_head_oh), .in(buf_error), .out(buf_error_head));
  // buf addr
  wire [31:1] buf_addr_mid, buf_addr_head, buf_addr_mid_prev;
  premux #(31, 16) buf_addr_mid_mux (.sel(buf_mid_oh), .in(buf_addr), .out(buf_addr_mid));
  premux #(31, 16) buf_addr_head_mux (.sel(buf_head_oh), .in(buf_addr), .out(buf_addr_head));
  premux #(31, 16) buf_addr_mid_prev_mux (.sel(buf_mid_prev_oh), .in(buf_addr), .out(buf_addr_mid_prev));
  
  // buf insn
  wire [31:0] buf_insn_head, buf_insn_mid_prev;
  premux #(32, 16) buf_insn_head_mux (.sel(buf_head_oh), .in(buf_insn), .out(buf_insn_head));
  premux #(32, 16) buf_insn_mid_prev_mux (.sel(buf_mid_prev_oh), .in(buf_insn), .out(buf_insn_mid_prev));
  
  // buf bptaken
  wire buf_bptaken_head;
  premux #(1, 16) buf_bptaken_head_mux (.sel(buf_head_oh), .in(buf_bptaken), .out(buf_bptaken_head));
  
  // buf bptag
  wire [15:0] buf_bptag_head;
  premux #(16, 16) buf_bptag_head_mux (.sel(buf_head_oh), .in(buf_bptag), .out(buf_bptag_head));


  // brpred interface
  assign fetch_bp_req = insn_br;
  assign fetch_bp_addr = buf_addr_mid[31:2];

  // decode interface
  assign fetch_de_valid = ~buf_empty & buf_valid[buf_head];
  assign fetch_de_error = buf_error_head;
  assign fetch_de_addr = buf_addr_head;
  assign fetch_de_insn = buf_insn_head;
  assign fetch_de_bptag = buf_bptag_head;
  assign fetch_de_bptaken = buf_bptaken_head;

  // pc
  wire [31:1] pc_set = {31{rst}} & 31'h08000000;
  wire [31:1] pc_rst = {31{rst}} & ~31'h08000000;

  wire [31:1] pc_flush = {rob_flush_pc, 1'b0};

  wire [31:0] insn_mp = buf_insn_mid_prev;
  wire [31:1] pc_br = $signed({buf_addr_mid_prev[31:2],1'b0}) + $signed({insn_mp[31],insn_mp[7],insn_mp[30:25],insn_mp[11:8]});
  //`ADD(31, pc_br, {buf_addr_mid_prev[31:2], 1'b0}, 
  //  {{20{insn_mp[31]}},insn_mp[7],insn_mp[30:25],insn_mp[11:8]});
  
  wire [31:1] pc_jal = $signed({buf_addr_mid_prev[31:2],1'b0}) + $signed({insn_mp[31],insn_mp[19:12],insn_mp[20],insn_mp[30:21]});
  //`ADD(31, pc_jal, {buf_addr_mid_prev[31:2], 1'b0},
  //  {{12{insn_mp[31]}},insn_mp[19:12],insn_mp[20],insn_mp[30:21]});

  wire [31:1] pc_inc = pc + 2;
  //`ADD(31, pc_inc, pc, 31'h02);
  
  wire [3:0] pc_sel;
  wire pc_dis;
  privector #(4, 1) pc_sel_prippf (.in({icache_beat, insn_jal_r, br_taken, rob_flush}),
    .invalid(pc_dis), .out(pc_sel));
  
  wire [31:1] pc_next;
  premux #(31, 4) pc_next_mux (.sel(pc_sel), .in({pc_inc, pc_jal, pc_br, pc_flush}),
    .out(pc_next));

  flop pc_flop [31:1] (.clk(clk), .rst(pc_rst), .set(pc_set), .enable(~pc_dis),
      .d(pc_next), .q(pc));


  // buf_tail
  wire buf_tail_pol_next;
  onehot_load #(16) buf_tail_ohmod (.clk(clk), .rst(rst|rob_flush), .load(setpc),
    .load_val(buf_mid_oh), .shift(icache_beat), .out(buf_tail_oh));
  
  mux #(1, 2) buf_tail_pol_next_mux (.sel(setpc), 
      .in({buf_mid_pol, buf_tail_pol ^ buf_tail_oh[15]}),
      .out(buf_tail_pol_next));

  flop buf_tail_pol_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0), 
      .enable(setpc | icache_beat), .d(buf_tail_pol_next), .q(buf_tail_pol));

  // debugging
  encoder #(16) tail_enc (.in(buf_tail_oh), .invalid(), .out(buf_tail));  


  // buf_mid
  onehot #(16) buf_mid_ohmod (.clk(clk), .rst(rst|rob_flush),
      .shift(icache_valid & ~setpc), .out(buf_mid_oh));

  flop buf_mid_pol_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0),
      .enable(icache_valid & ~setpc), .d(buf_mid_pol ^ buf_mid_oh[15]), .q(buf_mid_pol));

  // debugging
  encoder #(16) mid_enc (.in(buf_mid_oh), .invalid(), .out(buf_mid));


  // buf_head
  onehot #(16) buf_head_ohmod (.clk(clk), .rst(rst|rob_flush),
      .shift(decode_beat), .out(buf_head_oh));

  flop buf_head_pol_flop (.clk(clk), .rst(rst|rob_flush), .set(1'b0),
      .enable(decode_beat), .d(buf_head_pol ^ buf_head_oh[15]), .q(buf_head_pol));

  // debugging
  encoder #(16) head_enc (.in(buf_head_oh), .invalid(), .out(buf_head));

  
  // buf write ports
  // buf valid
  wire [15:0] buf_valid_rst_vec = {16{rst}} | ({16{icache_beat}} & buf_tail_oh);
  wire [15:0] buf_valid_set_vec = ({16{icache_valid & ~fetch_bp_req}} & buf_mid_oh) |
    ({16{bp_req_r}} & buf_mid_prev_oh) | ({16{gen_misalign_err}} & buf_tail_oh);
  
  flop buf_valid_flop [15:0] (.clk(clk), .rst(buf_valid_rst_vec), .set(buf_valid_set_vec),
    .enable(1'b0), .d(1'b0), .q(buf_valid));

  // buf error
  wire [15:0] buf_error_set = ({16{gen_misalign_err}} & buf_tail_oh) |
    ({16{icache_valid & icache_error}} & buf_mid_oh);
  wire [15:0] buf_error_rst = {16{icache_valid & ~icache_error}} & buf_mid_oh;
 
  flop buf_error_flop [15:0] (.clk(clk), .rst(buf_error_rst), .set(buf_error_set),
    .enable(1'b0), .d(1'b0), .q(buf_error));
  
  // buf addr
  wire [15:0] buf_addr_en = {16{gen_misalign_err|icache_beat}} & buf_tail_oh;
  flop #(31) buf_addr_flop [15:0] (.clk(clk), .rst(1'b0), .set(1'b0),
    .enable(buf_addr_en), .d(pc), .q(buf_addr));
  
  // buf insn
  wire [15:0] buf_insn_en = {16{icache_valid}} & buf_mid_oh;
  flop #(32) buf_insn_flop [15:0] (.clk(clk), .rst(1'b0), .set(1'b0),
    .enable(buf_insn_en), .d(icache_data), .q(buf_insn));

  // buf bptaken
  wire [15:0] buf_bp_en = {16{bp_req_r}} & buf_mid_prev_oh;
  flop buf_bptaken_flop [15:0] (.clk(clk), .rst(1'b0), .set(1'b0),
    .enable(buf_bp_en), .d(brpred_bptaken), .q(buf_bptaken));

  // buf bptag
  flop #(16) buf_bptag_flop [15:0] (.clk(clk), .rst(1'b0), .set(1'b0),
    .enable(buf_bp_en), .d(brpred_bptag), .q(buf_bptag));

  // buf
  /*always @(posedge clk)
    if(rst)
      buf_valid <= 0;
    else begin
      if(gen_misalign_err) begin
        buf_valid[buf_tail] <= 1;
      end

      if(icache_beat) begin
        buf_valid[buf_tail] <= 0;
      end

      if(icache_valid) begin
        if(~fetch_bp_req)
          buf_valid[buf_mid] <= 1;
      end

      if(bp_req_r) begin
        buf_valid[buf_mid_prev] <= 1;
      end
    end*/

  wire rst_tmp = rst | setpc;
  // bp_req_r
  flop bp_req_r_flop (.clk(clk), .rst(rst_tmp), .set(1'b0),
    .enable(1'b1), .d(fetch_bp_req), .q(bp_req_r));

  // insn_jal_r
  flop insn_jal_r_flop (.clk(clk), .rst(rst_tmp), .set(1'b0),
    .enable(1'b1), .d(insn_jal), .q(insn_jal_r));

  // jalr_halt_r
  flop jalr_halt_r_flop (.clk(clk), .rst(rst_tmp), .set(~rst_tmp & insn_jalr),
    .enable(1'b0), .d(1'b0), .q(jalr_halt_r));

  // misalign_err_r
  flop misalign_err_r_flop (.clk(clk), .rst(rst_tmp), .set(~rst_tmp & gen_misalign_err),
    .enable(1'b0), .d(1'b0), .q(misalign_err_r));
  
endmodule
