// reorder buffer and retirement unit
module rob(
  input         clk,
  input         rst,

  // decode interface
  input         decode_rob_valid,
  input         decode_error,
  input [1:0]   decode_ecause,
  input [6:0]   decode_retop,
  input [31:2]  decode_addr,
  input [5:0]   decode_rd,
  input [15:0]  decode_bptag,
  input         decode_bptaken,
  input [31:2]  decode_target,
  output        rob_full,
  output [7:0]  rob_robid,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [4:0]   wb_ecause,
  input [6:0]   wb_robid,
  input [31:0]  wb_result,

  // common signals
  output        rob_flush,

  // fetch interface
  output [31:2] rob_flush_pc,

  // rat interface
  output        rob_ret_valid,
  output [4:0]  rob_ret_rd,
  output [31:0] rob_ret_result,

  // brpred interface
  output        rob_ret_branch,
  output [15:0] rob_ret_bptag,
  output        rob_ret_bptaken,

  // lsq interface (out)
  output        rob_ret_store,

  // csr interface
  input [31:2]  csr_tvec,
  output        rob_csr_valid,
  output [31:2] rob_csr_epc,
  output [4:0]  rob_csr_ecause,
  output [31:0] rob_csr_tval);

  reg [127:0] buf_executed;
  reg [127:0] buf_error;
  reg [6:0]   buf_retop [0:127];
  reg [31:2]  buf_addr [0:127];
  reg [5:0]   buf_rd [0:127];
  reg [4:0]   buf_ecause [0:127];
  reg [31:0]  buf_result [0:127];
  reg [31:2]  buf_target [0:127];
  reg [15:0]  buf_bptag [0:127];
  reg [127:0] buf_bptaken;

  // insert at tail, remove at head
  reg [6:0]   buf_head, buf_tail;
  reg         buf_head_pol, buf_tail_pol;

  reg         ret_valid;
  reg         ret_error;
  reg [6:0]   ret_retop;
  reg [31:2]  ret_addr;
  reg [5:0]   ret_rd;
  reg [4:0]   ret_ecause;
  reg [31:0]  ret_result;
  reg [31:2]  ret_target;
  reg [15:0]  ret_bptag;
  reg         ret_bptaken;

  wire [7:0] buf_head_next;
  wire [6:0] ret_rd_addr;

  // forward buf_head when reading consecutive addrs
  assign buf_head_next = {buf_head_pol,buf_head} + 1;
  assign ret_rd_addr = ret_valid ? buf_head_next[6:0] : buf_head;

  // derived signals
  wire buf_empty, buf_full;
  assign buf_empty = (buf_head == buf_tail) & (buf_head_pol == buf_tail_pol);
  assign buf_full  = (buf_head == buf_tail) & (buf_head_pol != buf_tail_pol);

  wire decode_beat;
  assign decode_beat = decode_rob_valid & ~rob_full;

  wire br_result;
  assign br_result = ret_result[0] ^ ret_retop[5];

  wire ret_exc, ret_mispred;
  assign ret_exc = ret_valid & ret_error;
  assign ret_mispred = ret_valid & (ret_retop[4] | (ret_retop[6] & (br_result ^ ret_bptaken)));

  // decode interface
  assign rob_full = buf_full;
  assign rob_robid = {buf_tail_pol,buf_tail};

  // common signals
  assign rob_flush = ret_exc | ret_mispred;

  // fetch interface
  assign rob_flush_pc = ret_error ? csr_tvec : ret_target;

  // rat interface
  assign rob_ret_valid = ret_valid & ~ret_error & ~ret_rd[5];
  assign rob_ret_rd = ret_rd[4:0];
  assign rob_ret_result = ret_result;

  // brpred interface
  assign rob_ret_branch = ret_valid & ret_retop[6];
  assign rob_ret_bptag = ret_bptag;
  assign rob_ret_bptaken = br_result;

  // lsq interface (out)
  assign rob_ret_store = ret_valid & ~ret_error & ret_retop[3];

  // csr interface
  assign rob_csr_valid = ret_exc;
  assign rob_csr_epc = ret_addr;
  assign rob_csr_ecause = ret_ecause;
  assign rob_csr_tval = 0; // TODO

  // buf_head
  always @(posedge clk)
    if(rst | rob_flush) begin
      buf_head <= 0;
      buf_head_pol <= 0;
    end else if(ret_valid)
      {buf_head_pol,buf_head} <= buf_head_next;

  // buf_tail
  always @(posedge clk)
    if(rst | rob_flush) begin
      buf_tail <= 0;
      buf_tail_pol <= 0;
    end else if(decode_beat)
      {buf_tail_pol,buf_tail} <= {buf_tail_pol,buf_tail} + 1;

  // buf read
  always @(posedge clk)
    if(rst | rob_flush)
      ret_valid <= 0;
    else begin
      ret_valid <= buf_executed[ret_rd_addr] & ~buf_empty;
      ret_error <= buf_error[ret_rd_addr];
      ret_retop <= buf_retop[ret_rd_addr];
      ret_addr <= buf_addr[ret_rd_addr];
      ret_rd <= buf_rd[ret_rd_addr];
      ret_ecause <= buf_ecause[ret_rd_addr];
      ret_result <= buf_result[ret_rd_addr];
      ret_target <= buf_target[ret_rd_addr];
      ret_bptag <= buf_bptag[ret_rd_addr];
      ret_bptaken <= buf_bptaken[ret_rd_addr];
    end

  // buf write
  always @(posedge clk) begin
    if(decode_beat) begin
      buf_executed[buf_tail] <= decode_error | decode_retop[3];
      buf_error[buf_tail] <= decode_error;
      buf_retop[buf_tail] <= decode_retop;
      buf_addr[buf_tail] <= decode_addr;
      buf_rd[buf_tail] <= decode_rd;
      buf_ecause[buf_tail] <= {3'b0,decode_ecause};
      buf_target[buf_tail] <= decode_target;
      buf_bptag[buf_tail] <= decode_bptag;
      buf_bptaken[buf_tail] <= decode_bptaken;
    end

    if(wb_valid) begin
      buf_executed[wb_robid] <= 1;
      buf_error[wb_robid] <= wb_error;
      buf_ecause[wb_robid] <= wb_ecause;
      buf_result[wb_robid] <= wb_result;
    end
  end

  always @(posedge clk)
    if(ret_valid)
      top.trace_rob_retire(
        buf_head,
        ret_addr,
        ret_error,
        ret_ecause,
        ret_rd,
        ret_result);

endmodule
