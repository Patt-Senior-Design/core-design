// instruction cache
module icache(
  input         clk,
  input         rst,

  // fetch interface
  input         fetch_ic_req,
  input [31:2]  fetch_ic_addr,
  input         fetch_ic_flush,
  output        icache_ready,
  output        icache_valid,
  output        icache_error,
  output [31:0] icache_data);

  reg [31:0] storage [0:16383]; // 64K

  localparam STDERR = 32'h80000002;

  reg [128*8-1:0] memfile;
  integer i, fd;
  initial begin
    for(i = 0; i < 16384; i=i+1)
      storage[i] = 0;

    if(!$value$plusargs("memfile=%s", memfile))
      memfile = "memory.hex";

    fd = $fopen(memfile, "r");
    if(!fd) begin
      $fdisplay(STDERR, "Cannot open memfile %0s", memfile);
      $finish;
    end
    $fclose(fd);

    $readmemh(memfile, storage);
  end

  reg        req_s0, req_s1;
  reg [31:2] addr_s0, addr_s1;
  always @(posedge clk)
    if(rst | fetch_ic_flush) begin
      req_s0 <= 0;
      req_s1 <= 0;
    end else begin
      req_s0 <= fetch_ic_req;
      req_s1 <= req_s0;
      addr_s0 <= fetch_ic_addr;
      addr_s1 <= addr_s0;
    end

  assign icache_ready = 1;
  assign icache_valid = req_s1;
  assign icache_error = 0;
  assign icache_data = storage[addr_s1[15:2]];

endmodule
