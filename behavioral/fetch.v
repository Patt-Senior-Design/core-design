module fetch ( icache_ready, icache_valid, icache_error, icache_data,
               brpred_bptaken, brpred_bptag, brpred_addr,
               decode_stall,
               rob_flush, 

               ic_req, ic_addr, ic_flush,
               bp_req, bp_addr, 
               de_valid, de_error, de_addr, de_insn, de_bptag, de_bptaken);
   
   input icache_ready, icache_valid, icache_error;
   input[31:0] icache_data;
   input brpred_bptaken;
   input[13:0] brpred_bptag;
   input[29:0] brpred_addr;
   input decode_stall;
   input rob_flush;

   output ic_req, ic_flush;
   output[29:0] ic_addr;
   output bp_req;
   output[29:0] bp_addr;
   output de_valid, de_error, de_bptag, de_bptaken;
   output[29:0] de_addr;
   output[31:0] de_insn;
   output[13:0] de_bptag;

   

endmodule
