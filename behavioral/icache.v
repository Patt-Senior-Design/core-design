module icache( req, addr, flush,
               ready, valid, error, data);

   input req, flush;
   input[29:0] addr;

   output ready, valid, error;
   output[31:0] data;

endmodule
