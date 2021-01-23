module top();

  reg clk;
  reg rst;
  cpu cpu(
    .clk(clk),
    .rst(rst));

  always
    #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    #100;
    rst = 0;
  end

  // memories for use by the caches
  localparam
    ROM_BASE = 32'h10000000/4,
    ROM_SIZE = (64*1024)/4,
    RAM_BASE = 32'h20000000/4,
    RAM_SIZE = (4*1024*1024)/4;

  reg [31:0] mem_rom [0:ROM_SIZE-1];
  reg [31:0] mem_ram [0:RAM_SIZE-1];

  reg [128*8-1:0] memfile;
  integer i, fd;
  initial begin
    for(i = 0; i < ROM_SIZE; i=i+1)
      mem_rom[i] = 0;
    for(i = 0; i < RAM_SIZE; i=i+1)
      mem_ram[i] = 0;

    if(!$value$plusargs("memfile=%s", memfile))
      memfile = "memory.hex";

    fd = $fopen(memfile, "r");
    if(!fd) begin
      $fdisplay(STDERR, "Cannot open memfile %0s", memfile);
      $finish;
    end
    $fclose(fd);

    $readmemh(memfile, mem_rom);
  end

  task automatic mem_read(
    input [31:2]      addr,
    output reg [31:0] rdata);

    begin
      if(addr >= ROM_BASE && addr < (ROM_BASE+ROM_SIZE))
        rdata = mem_rom[addr-ROM_BASE];
      else if(addr >= RAM_BASE && addr < (RAM_BASE+RAM_SIZE))
        rdata = mem_ram[addr-RAM_BASE];
      else
        rdata = 0;
    end
  endtask

  task mem_write(
    input [31:2] addr,
    input [3:0]  wmask,
    input [31:0] wdata);

    integer i;
    begin
      if(addr >= RAM_BASE && addr < (RAM_BASE+RAM_SIZE))
        for(i = 0; i < 4; i=i+1)
          if(wmask[i])
            mem_ram[addr-RAM_BASE][i*8+:8] = wdata[i*8+:8];
    end
  endtask

  localparam STDOUT = 32'h80000001;
  localparam STDERR = 32'h80000002;

  reg [128*8-1:0] tracefile;
  integer         tracefd;
  initial begin
    $dumpfile("top.vcd");
    $dumpvars;

    tracefd = STDOUT;
    if($value$plusargs("tracefile=%s", tracefile)) begin
      tracefd = $fopen(tracefile, "w");
      if(!tracefd) begin
        $fdisplay(STDERR, "Cannot open tracefile %0s", tracefile);
        $finish;
      end
    end
  end

  // indexed by robid
  reg [31:0]  trace_insn [0:127];
  reg [31:0]  trace_imm [0:127];
  reg [127:0] trace_uses_mem;
  reg [3:0]   trace_memop [0:127];
  reg [31:0]  trace_membase [0:127];
  reg [31:0]  trace_memdata [0:127];

  // indexed by lsqid
  reg [6:0]   trace_robid [0:31];

  task trace_decode(
    input [6:0]  robid,
    input [31:0] insn,
    input [31:0] imm);

    begin
      trace_insn[robid] = insn;
      trace_imm[robid] = imm;
      trace_uses_mem[robid] = 0;
    end
  endtask

  task trace_lsq_dispatch(
    input [6:0] robid,
    input [4:0] lsqid,
    input [3:0] op,
    input [31:0] base,
    input [31:0] wdata);

    begin
      trace_robid[lsqid] = robid;
      trace_uses_mem[robid] = 1;
      trace_memop[robid] = op;
      trace_membase[robid] = base;
      trace_memdata[robid] = wdata;
    end
  endtask

  task automatic trace_lsq_base(
    input [4:0]  lsqid,
    input [31:0] base);

    reg [6:0] robid;
    begin
      robid = trace_robid[lsqid];
      trace_membase[robid] = base;
    end
  endtask

  task trace_lsq_wdata(
    input [4:0]  lsqid,
    input [31:0] wdata);

    reg [6:0] robid;
    begin
      robid = trace_robid[lsqid];
      trace_memdata[robid] = wdata;
    end
  endtask

  task trace_rob_retire(
    input [6:0]  robid,
    input [31:2] addr,
    input        error,
    input [4:0]  ecause,
    input [5:0]  rd,
    input [31:0] result);

    reg [31:0] memaddr;
    begin
      memaddr = trace_membase[robid] + trace_imm[robid];

      $fwrite(tracefd, "core   0: 3 0x%08x (0x%08x)", {addr,2'b0}, trace_insn[robid]);
      if(error)
        $fwrite(tracefd, " error %0d", ecause);
      else begin
        if(~rd[5])
          $fwrite(tracefd, " x%2d 0x%08x", rd[4:0], result);
        if(trace_uses_mem[robid]) begin
          $fwrite(tracefd, " mem 0x%08x", memaddr);
          if(trace_memop[robid][3])
            case(trace_memop[robid][1:0])
              2'b00: // byte write
                // needs to be 01 rather than 02 to match spike
                $fwrite(tracefd, " 0x%01x", trace_memdata[robid]);
              2'b01: // halfword write
                $fwrite(tracefd, " 0x%04x", trace_memdata[robid]);
              default: // word write
                $fwrite(tracefd, " 0x%08x", trace_memdata[robid]);
            endcase
        end
      end
      $fdisplay(tracefd);

      // htif tohost write termination
      if(~error & trace_uses_mem[robid] & trace_memop[robid][3] & (memaddr == 32'h30000000))
        $finish;
    end
  endtask

endmodule
