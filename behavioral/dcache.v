// data cache
module dcache(
  input         clk,
  input         rst,

  // lsq interface
  input         lsq_dc_req,
  input [3:0]   lsq_dc_op,
  input [31:0]  lsq_dc_addr,
  input [3:0]   lsq_dc_lsqid,
  input [31:0]  lsq_dc_wdata,
  input         lsq_dc_flush,
  output        dcache_ready,
  output        dcache_valid,
  output        dcache_error,
  output [3:0]  dcache_lsqid,
  output [31:0] dcache_rdata);

  reg        req_s0, req_s1;
  reg [3:0]  op_s0, op_s1;
  reg [31:0] addr_s0, addr_s1;
  reg [3:0]  lsqid_s0, lsqid_s1;
  reg [31:0] wdata_s0, rdata_raw, rdata_s1;
  always @(posedge clk)
    if(rst) begin
      req_s0 <= 0;
      req_s1 <= 0;
    end else begin
      // preserve incoming writes during a flush
      req_s0 <= lsq_dc_req & (lsq_dc_op[0] | ~lsq_dc_flush);
      op_s0 <= lsq_dc_op;
      addr_s0 <= lsq_dc_addr;
      lsqid_s0 <= lsq_dc_lsqid;
      wdata_s0 <= lsq_dc_wdata;

      req_s1 <= req_s0 & ~op_s0[0] & ~lsq_dc_flush;
      lsqid_s1 <= lsqid_s0;

      // TODO handle misalignment either in lsq or here
      if(req_s0)
        if(op_s0[0])
          // store op
          case(op_s0[2:1])
            2'b00: // SB
              top.mem_write(addr_s0[31:2], 4'b0001 << addr_s0[1:0], wdata_s0 << (addr_s0[1:0]*8));
            2'b01: // SH
              top.mem_write(addr_s0[31:2], 4'b0011 << (addr_s0[1]*2), wdata_s0 << (addr_s0[1]*16));
            default: // SW
              top.mem_write(addr_s0[31:2], 4'b1111, wdata_s0);
          endcase
        else begin
          // load op
          top.mem_read(addr_s0[31:2], rdata_raw);
          case(op_s0[3:1])
            3'b000: // LB
              rdata_s1 <= $signed(rdata_raw[addr_s0[1:0]*8+:8]);
            3'b100: // LBU
              rdata_s1 <= rdata_raw[addr_s0[1:0]*8+:8];
            3'b001: // LH
              rdata_s1 <= $signed(rdata_raw[addr_s0[1]*16+:16]);
            3'b101: // LHU
              rdata_s1 <= rdata_raw[addr_s0[1]*16+:16];
            default: // LW
              rdata_s1 <= rdata_raw;
          endcase
        end
    end

  assign dcache_ready = 1;
  assign dcache_valid = req_s1;
  assign dcache_error = 0;
  assign dcache_lsqid = lsqid_s1;
  assign dcache_rdata = rdata_s1;

endmodule
