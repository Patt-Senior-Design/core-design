module brpred( fetch_req, fetch_addr,
               rob_flush, rob_ret_valid, rob_ret_brtag, rob_ret_brtaken,
               bp_taken, bp_tag, bp_addr);

   input fetch_req;
   input[29:0] fetch_addr;
   input rob_flush, rob_ret_valid, rob_brtaken;
   input[13:0] rob_ret_brtaken;

   output bp_taken;
   output[13:0] bp_tag;
   output[29:0] bp_addr;


endmodule
