module top();

  reg clk;
  reg rst;
  cpu cpu(
    .clk(clk),
    .rst(rst));

  always
    #5 clk = ~clk;

  localparam STDERR = 32'h80000002;

  reg [128*8-1:0] tracefile;
  integer         tracefd;
  initial begin
    $dumpfile("top.vcd");
    $dumpvars;

    tracefd = 0;
    if($value$plusargs("tracefile=%s", tracefile)) begin
      tracefd = $fopen(tracefile, "w");
      if(!tracefd) begin
        $fdisplay(STDERR, "Cannot open tracefile %0s", tracefile);
        $finish;
      end
    end

    clk = 0;
    rst = 1;
    #100;
    rst = 0;
  end

  // indexed by robid
  reg [31:0]  trace_insn [0:127];
  reg [127:0] trace_uses_mem;
  reg [3:0]   trace_memop [0:127];
  reg [31:0]  trace_memaddr [0:127];
  reg [31:0]  trace_memdata [0:127];

  // indexed by lsqid
  reg [6:0]   trace_robid [0:31];

  task trace_decode(
    input [6:0]  robid,
    input [31:0] insn);

    begin
      trace_insn[robid] = insn;
      trace_uses_mem[robid] = 0;
    end
  endtask

  task trace_lsq_dispatch(
    input [6:0] robid,
    input [4:0] lsqid,
    input [3:0] op);

    begin
      trace_robid[lsqid] = robid;
      trace_uses_mem[robid] = 1;
      trace_memop[robid] = op;
    end
  endtask

  task trace_lsq_addrgen(
    input [4:0]  lsqid,
    input [31:0] addr);

    reg [6:0] robid;
    begin
      robid = trace_robid[lsqid];
      trace_memaddr[robid] = addr;
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

    begin
      $fwrite(tracefd, "core   0: 3 0x%08x (0x%08x)", {addr,2'b0}, trace_insn[robid]);
      if(error)
        $fwrite(tracefd, " error %0d", ecause);
      else begin
        if(~rd[5])
          $fwrite(tracefd, " x%2d 0x%08x", rd[4:0], result);
        if(trace_uses_mem[robid]) begin
          $fwrite(tracefd, " mem 0x%08x", trace_memaddr[robid]);
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
      if(~error & trace_uses_mem[robid] & trace_memop[robid][3] & (trace_memaddr[robid] == 32'h30000000))
        $finish;
    end
  endtask

endmodule
