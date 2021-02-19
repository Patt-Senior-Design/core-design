module top();

  reg clk;
  reg rst;
  cpu cpu(
    .clk(clk),
    .rst(rst));

  always
    #0.5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
    $dumplimit(32*1024*1024*1024);

    clk = 0;
    rst = 1;
    #10;
    rst = 0;
  end

  // standard fds
  localparam STDOUT = 32'h80000001;
  localparam STDERR = 32'h80000002;

  // memory map constants
  localparam
    ROM_BASE   = 32'h10000000/4,
    ROM_SIZE   = (256*1024)/4,
    RAM_BASE   = 32'h20000000/4,
    RAM_SIZE   = (128*1024*1024)/4,
    DBG_TOHOST = 32'h30000000/4,
    UART_STAT  = 32'h30010000/4,
    UART_RX    = 32'h30010004/4,
    UART_TX    = 32'h30010008/4;

  // uart status bits
  localparam
    UART_RXEMPTY = 4'b0001,
    UART_RXFULL  = 4'b0010,
    UART_TXEMPTY = 4'b0100,
    UART_TXFULL  = 4'b1000;

  task automatic openargfile(
    input [16*8-1:0] argname,
    input [3*8-1:0]  mode,
    output integer   fd,
    input integer    defaultfd);

    reg [19*8-1:0]  argstr;
    reg [128*8-1:0] argfile;
    begin
      fd = defaultfd;
      $swrite(argstr, "%0s=%%s", argname);
      if($value$plusargs(argstr, argfile)) begin
        fd = $fopen(argfile, mode);
        if(!fd) begin
          $fdisplay(STDERR, "Cannot open file %0s", argfile);
          #1 $finish;
        end
      end
    end
  endtask

  reg [31:0] mem_rom [0:ROM_SIZE-1];
  reg [31:0] mem_ram [0:RAM_SIZE-1];

  reg [128*8-1:0] memfile;
  integer         i, memfd;
  initial begin
    for(i = 0; i < ROM_SIZE; i=i+1)
      mem_rom[i] = 0;
    for(i = 0; i < RAM_SIZE; i=i+1)
      mem_ram[i] = 0;

    if($value$plusargs("memfile=%s", memfile)) begin
      memfd = $fopen(memfile, "r");
      if(!memfd) begin
        $fdisplay(STDERR, "Cannot open memfile %0s", memfile);
        #1 $finish;
      end
      $fclose(memfd);

      $readmemh(memfile, mem_rom);
    end
  end

  reg [128*8-1:0] uartfile;
  integer         uartfd;
  initial
    openargfile("uartfile", "w", uartfd, STDOUT);

  task automatic mem_read(
    input [31:2]      addr,
    output reg [31:0] rdata);

    begin
      if(addr >= ROM_BASE && addr < (ROM_BASE+ROM_SIZE))
        rdata = mem_rom[addr-ROM_BASE];
      else if(addr >= RAM_BASE && addr < (RAM_BASE+RAM_SIZE))
        rdata = mem_ram[addr-RAM_BASE];
      else if(addr == UART_STAT)
        rdata = UART_TXEMPTY | UART_RXEMPTY;
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
      if(addr >= RAM_BASE && addr < (RAM_BASE+RAM_SIZE)) begin
        for(i = 0; i < 4; i=i+1)
          if(wmask[i])
            mem_ram[addr-RAM_BASE][i*8+:8] = wdata[i*8+:8];
      end else if(addr == UART_TX && wmask[0])
        $fwrite(uartfd, "%c", wdata[7:0]);
    end
  endtask

  integer tracefd, logfd;
  initial begin
    openargfile("tracefile", "w", tracefd, 0);
    openargfile("logfile", "w", logfd, 0);
  end

  // indexed by robid
  reg [31:0]  trace_insn [0:127];
  reg [31:0]  trace_imm [0:127];
  reg [127:0] trace_uses_mem;
  reg [3:0]   trace_memop [0:127];
  reg [31:0]  trace_membase [0:127];
  reg [31:0]  trace_memdata [0:127];
  reg [127:0] trace_writes_csr;
  // reuse trace_membase for csr address
  // reuse trace_memdata for csr data

  // indexed by lsqid
  reg [6:0]   trace_robid [0:31];

  integer     trace_instret;
  integer     trace_branches;
  integer     trace_mispreds;
  initial begin
    trace_instret = 0;
    trace_branches = 0;
    trace_mispreds = 0;
  end

  task trace_decode(
    input [6:0]  robid,
    input [31:0] insn,
    input [31:0] imm);

    begin
      trace_insn[robid] = insn;
      trace_imm[robid] = imm;
      trace_uses_mem[robid] = 0;
      trace_writes_csr[robid] = 0;
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

  task trace_csr_write(
    input [6:0]  robid,
    input [11:0] addr,
    input [31:0] data);

    // reuse trace_membase for csr address
    // reuse trace_memdata for csr data
    begin
      trace_writes_csr[robid] = 1;
      trace_membase[robid] = addr;
      trace_memdata[robid] = data;
    end
  endtask

  function [16*8-1:0] csr_name(
    input [11:0] addr);

    case(addr)
      12'h300: csr_name = "mstatus";
      12'h301: csr_name = "misa";
      12'h302: csr_name = "medeleg";
      12'h303: csr_name = "mideleg";
      12'h304: csr_name = "mie";
      12'h305: csr_name = "mtvec";
      12'h306: csr_name = "mcounteren";
      12'h310: csr_name = "mstatush";
      12'h340: csr_name = "mscratch";
      12'h341: csr_name = "mepc";
      12'h342: csr_name = "mcause";
      12'h343: csr_name = "mtval";
      12'h344: csr_name = "mip";
      12'h34a: csr_name = "mtinst";
      12'h34b: csr_name = "mtval2";
      12'hb00: csr_name = "mcycle";
      12'hb02: csr_name = "minstret";
      12'hb80: csr_name = "mcycleh";
      12'hb82: csr_name = "minstreth";
      12'hf11: csr_name = "mvendorid";
      12'hf12: csr_name = "marchid";
      12'hf13: csr_name = "mimpid";
      12'hf14: csr_name = "mhartid";
      default: csr_name = "<unknown>";
    endcase
  endfunction

  integer watchdog;
  task trace_rob_retire(
    input [6:0]  robid,
    input [6:0]  retop,
    input [31:2] addr,
    input        error,
    input        mispred,
    input [4:0]  ecause,
    input [5:0]  rd,
    input [31:0] result);

    reg [31:0] memaddr;
    begin
      watchdog = 0;

      trace_instret = trace_instret + 1;
      if(retop[6]) begin
        trace_branches = trace_branches + 1;
        if(mispred)
          trace_mispreds = trace_mispreds + 1;
      end
      memaddr = trace_membase[robid] + trace_imm[robid];

      if(tracefd) begin
        $fwrite(tracefd, "core   0: 3 0x%x (0x%x)", {addr,2'b0}, trace_insn[robid]);
        if(error)
          $fwrite(tracefd, " error %0d", ecause);
        else begin
          if(~rd[5])
            $fwrite(tracefd, " x%d 0x%x", rd[4:0], result);
          if(trace_uses_mem[robid]) begin
            $fwrite(tracefd, " mem 0x%x", memaddr);
            if(trace_memop[robid][3])
              case(trace_memop[robid][1:0])
                2'b00: // byte write
                  // needs to be %0x to match spike
                  $fwrite(tracefd, " 0x%0x", trace_memdata[robid][7:0]);
                2'b01: // halfword write
                  $fwrite(tracefd, " 0x%x", trace_memdata[robid][15:0]);
                default: // word write
                  $fwrite(tracefd, " 0x%x", trace_memdata[robid]);
              endcase
            else if(trace_memop[robid][1:0] == 2'b11) begin
              // lbcmp makes multiple sequential accesses
              $fwrite(tracefd, " mem 0x%x", memaddr+8);
              $fwrite(tracefd, " mem 0x%x", memaddr+16);
              $fwrite(tracefd, " mem 0x%x", memaddr+24);
            end
          end
          if(trace_writes_csr[robid])
            $fwrite(tracefd, " c%0d_%0s 0x%x", trace_membase[robid],
              csr_name(trace_membase[robid]), trace_memdata[robid]);
        end
        $fdisplay(tracefd);
      end

      if(logfd) begin
        $fwrite(logfd, "%0d ret %x", $stime, {addr,2'b0});
        if(~rd[5])
          $fwrite(logfd, " x%0d=%x", rd[4:0], result);
        $fdisplay(logfd);
      end

      // htif tohost write termination
      if(~error & trace_uses_mem[robid] & trace_memop[robid][3] & (memaddr[31:2] == DBG_TOHOST)) begin
        printstats();
        $finish;
      end
    end
  endtask

  always @(posedge clk) begin
    watchdog = watchdog + 1;
    if(watchdog > 1000) begin
      $display("\nERROR: 1000 cycles elapsed since last insn retired. Terminating.\n");
      $finish;
    end
  end

  integer trace_cycles;
  task printstats();
    begin
      trace_cycles = $stime;
      $display("*** SUMMARY STATISTICS ***");
      $display("Cycles elapsed: %0d", trace_cycles);
      $display("Instructions retired: %0d", trace_instret);
      $display("Average CPI: %.3f", $itor(trace_cycles) / $itor(trace_instret));
      $display("Branch prediction accuracy: %.2f", 1.0 - ($itor(trace_mispreds) / $itor(trace_branches)));
    end
  endtask

  task log_dcache_req(
    input [3:0]  lsqid,
    input [3:0]  op,
    input [31:0] addr,
    input [31:0] wdata);

    reg [5*8-1:0] mnemonic;
    if(logfd) begin
      casez(op)
        4'b000_0: mnemonic = "lb";
        4'b001_0: mnemonic = "lh";
        4'b010_0: mnemonic = "lw";
        4'b100_0: mnemonic = "lbu";
        4'b101_0: mnemonic = "lhu";
        4'b000_1: mnemonic = "sb";
        4'b001_1: mnemonic = "sh";
        4'b010_1: mnemonic = "sw";
        4'b?11_0: mnemonic = "lbcmp";
        default: mnemonic = "???";
      endcase
      $fwrite(logfd, "%0d %0s %x", $stime, mnemonic, addr);
      if(op[0])
        $fwrite(logfd, " %x", wdata);
      else begin
        if(mnemonic == "lbcmp")
          $fwrite(logfd, " %2x", wdata[7:0]);
        $fwrite(logfd, " %0d", lsqid);
      end
      $fdisplay(logfd);
    end
  endtask

  task log_dcache_resp(
    input [3:0]  lsqid,
    input        error,
    input [31:0] rdata);

    if(logfd) begin
      $fwrite(logfd, "%0d resp %0d", $stime, lsqid);
      if(error)
        $fwrite(logfd, " error");
      else
        $fwrite(logfd, " %x", rdata);
      $fdisplay(logfd);
    end
  endtask

  task log_rob_flush();
    if(logfd)
      $fdisplay(logfd, "%0d flush", $stime);
  endtask

endmodule
