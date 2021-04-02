`include "buscmd.vh"

module top();

  reg clk/*verilator public*/;
  reg rst/*verilator public*/;
  cpu cpu(
    .clk(clk),
    .rst(rst));

`ifdef VERILATOR
  import "DPI-C" task tb_log_bus_cycle(input bit nack, input bit hit, input bit [2:0] cmd, input bit [4:0] tag, input bit [31:6] addr);
  import "DPI-C" task tb_log_bus_data(input bit [2:0] index, input bit [63:0] data);
  import "DPI-C" task tb_log_dcache_req(input bit [3:0] lsqid, input bit [3:0] op, input bit [31:0] addr, input bit [31:0] wdata);
  import "DPI-C" task tb_log_dcache_resp(input bit [3:0] lsqid, input bit error, input bit [31:0] rdata);
  import "DPI-C" task tb_log_lsq_inflight(input bit [15:0] lq_valid, input bit [15:0] sq_valid);
  import "DPI-C" task tb_log_rob_flush();
  import "DPI-C" task tb_mem_read(input bit [31:2] addr, output bit [31:0] rdata);
  import "DPI-C" task tb_trace_csr_write(input bit [6:0] robid, input bit [11:0] addr, input bit [31:0] data);
  import "DPI-C" task tb_trace_decode(input bit [6:0] robid, input bit [31:0] insn, input bit [31:0] imm);
  import "DPI-C" task tb_trace_lsq_base(input bit [4:0] lsqid, input bit [31:0] base);
  import "DPI-C" task tb_trace_lsq_dispatch(input bit [6:0] robid, input bit [4:0] lsqid, input bit [3:0] op, input bit [31:0] base, input bit [31:0] wdata);
  import "DPI-C" task tb_trace_lsq_wdata(input bit [4:0] lsqid, input bit [31:0] wdata);
  import "DPI-C" task tb_trace_rob_retire(input bit [6:0] robid, input bit [6:0] retop, input bit [31:2] addr, input bit error, input bit mispred, input bit [4:0] ecause, input bit [5:0] rd, input bit [31:0] result);
  import "DPI-C" task tb_uart_tx(input bit [7:0] c);
`else
  always
    #0.5 clk = ~clk;

  initial begin
    $dumpfile("top.vcd");
    $dumpvars;
    $dumplimit(32*1024*1024*1024);

    clk = 1;
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
    ROM_SIZE   = (16*1024*1024)/4,
    DBG_TOHOST = 32'h30000000/4;

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

  reg [128*8-1:0] memfile;
  integer         i, memfd;
  initial begin
    for(i = 0; i < ROM_SIZE; i=i+1)
      mem_rom[i] = 0;

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

  task automatic tb_mem_read(
    input [31:2]      addr,
    output reg [31:0] rdata);

    if(addr >= ROM_BASE && addr < (ROM_BASE+ROM_SIZE))
      rdata = mem_rom[addr-ROM_BASE];
    else
      rdata = 0;
  endtask

  task tb_uart_tx(
    input [7:0] char);

    $fwrite(uartfd, "%c", char);
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

  integer     j;
  integer     trace_instret;
  integer     trace_branches;
  integer     trace_mispreds;
  integer     trace_rob_inflight;
  integer     trace_rob_inflight_hist [0:128];
  integer     trace_lq_inflight_hist [0:16];
  integer     trace_sq_inflight_hist [0:16];
  initial begin
    trace_instret = 0;
    trace_branches = 0;
    trace_mispreds = 0;
    trace_rob_inflight = 0;
    for(j = 0; j < 129; j=j+1)
      trace_rob_inflight_hist[j] = 0;
    for(j = 0; j < 17; j=j+1) begin
      trace_lq_inflight_hist[j] = 0;
      trace_sq_inflight_hist[j] = 0;
    end
  end

  always @(posedge clk)
    if(~rst)
      trace_rob_inflight_hist[trace_rob_inflight]
        = trace_rob_inflight_hist[trace_rob_inflight] + 1;

  task tb_trace_decode(
    input [6:0]  robid,
    input [31:0] insn,
    input [31:0] imm);

    begin
      trace_insn[robid] = insn;
      trace_imm[robid] = imm;
      trace_uses_mem[robid] = 0;
      trace_writes_csr[robid] = 0;

      trace_rob_inflight = trace_rob_inflight + 1;
    end
  endtask

  task tb_trace_lsq_dispatch(
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

  task automatic tb_trace_lsq_base(
    input [4:0]  lsqid,
    input [31:0] base);

    reg [6:0] robid;
    begin
      robid = trace_robid[lsqid];
      trace_membase[robid] = base;
    end
  endtask

  task tb_trace_lsq_wdata(
    input [4:0]  lsqid,
    input [31:0] wdata);

    reg [6:0] robid;
    begin
      robid = trace_robid[lsqid];
      trace_memdata[robid] = wdata;
    end
  endtask

  task tb_trace_csr_write(
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
      12'h7c0: csr_name = "muarttx";
      12'h7d0: csr_name = "mbfsstat";
      12'h7d1: csr_name = "mbfsroot";
      12'h7d2: csr_name = "mbfstarg";
      12'h7d3: csr_name = "mbfsqbase";
      12'h7d4: csr_name = "mbfsqsize";
      12'h7e0: csr_name = "ml2stat";
      12'hb00: csr_name = "mcycle";
      12'hb02: csr_name = "minstret";
      12'hb80: csr_name = "mcycleh";
      12'hb82: csr_name = "minstreth";
      12'hf11: csr_name = "mvendorid";
      12'hf12: csr_name = "marchid";
      12'hf13: csr_name = "mimpid";
      12'hf14: csr_name = "mhartid";
      12'hfc0: csr_name = "muartstat";
      12'hfc1: csr_name = "muartrx";
      default: csr_name = "<unknown>";
    endcase
  endfunction

  integer watchdog;
  task tb_trace_rob_retire(
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
      trace_rob_inflight = trace_rob_inflight - 1;

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
    if(watchdog > 5000) begin
      $display("\nERROR: 2000 cycles elapsed since last insn retired. Terminating.\n");
      $finish;
    end
  end

  integer k;
  integer trace_cycles;
  task printstats();
    begin
      trace_cycles = $stime;
      $display("*** SUMMARY STATISTICS ***");
      $display("Cycles elapsed: %0d", trace_cycles);
      $display("Instructions retired: %0d", trace_instret);
      $display("Average CPI: %.3f", $itor(trace_cycles) / $itor(trace_instret));
      $display("Branch prediction accuracy: %.2f", 1.0 - ($itor(trace_mispreds) / $itor(trace_branches)));

      $write("ROB occupancy histogram: ");
      for(k = 0; k < 129; k=k+1)
        $write("%0d,", trace_rob_inflight_hist[k]);
      $display();

      $write("LQ occupancy histogram: ");
      for(k = 0; k < 17; k=k+1)
        $write("%0d,", trace_lq_inflight_hist[k]);
      $display();

      $write("SQ occupancy histogram: ");
      for(k = 0; k < 17; k=k+1)
        $write("%0d,", trace_sq_inflight_hist[k]);
      $display();
    end
  endtask

  task tb_log_dcache_req(
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

  task tb_log_dcache_resp(
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

  task tb_log_rob_flush();
    begin
      trace_rob_inflight = 0;
      if(logfd)
        $fdisplay(logfd, "%0d flush", $stime);
    end
  endtask

  reg [63:0] bus_data [0:7];

  task tb_log_bus_data(
    input [2:0]  index,
    input [63:0] data);

    if(logfd)
      bus_data[index] = data;
  endtask

  task tb_log_bus_cycle(
    input        nack,
    input        hit,
    input [2:0]  cmd,
    input [4:0]  tag,
    input [31:6] addr);

    integer       i;
    reg [7*8-1:0] cmd_name;
    if(logfd) begin
      case(cmd)
        `CMD_BUSRD: cmd_name = "BusRd";
        `CMD_BUSRDX: cmd_name = "BusRdX";
        `CMD_BUSUPGR: cmd_name = "BusUpgr";
        `CMD_FILL: cmd_name = "Fill";
        `CMD_FLUSH: cmd_name = "Flush";
        default: cmd_name = "???";
      endcase

      $fwrite(logfd, "%0d bus %0d:%0d %0s %x", $stime,
        tag[4:3], tag[2:0], cmd_name, {addr,6'b0});
      if(cmd == `CMD_FILL || cmd == `CMD_FLUSH)
        for(i = 0; i < 8; i=i+1)
          $fwrite(logfd, " %x", bus_data[i]);
      if(nack)
        $fwrite(logfd, " NACK");
      if(hit)
        $fwrite(logfd, " Hit");
      $fdisplay(logfd);
    end
  endtask

  task tb_log_lsq_inflight(
    input [15:0] lq_valid,
    input [15:0] sq_valid);

    integer i, cnt;
    begin
      cnt = 0;
      for(i = 0; i < 16; i=i+1)
        if(lq_valid[i])
          cnt = cnt + 1;
      trace_lq_inflight_hist[cnt] = trace_lq_inflight_hist[cnt] + 1;

      cnt = 0;
      for(i = 0; i < 16; i=i+1)
        if(sq_valid[i])
          cnt = cnt + 1;
      trace_sq_inflight_hist[cnt] = trace_sq_inflight_hist[cnt] + 1;
    end
  endtask
`endif

endmodule
