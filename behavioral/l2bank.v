// l2 data bank
module l2bank(
  input             clk,
  input             rst,

  // l2data interface (in)
  input             l2data_bank_valid,
  input             l2data_bank_wen,
  input [11:0]      l2data_bank_addr,
  input [7:0]       l2data_bank_wmask,
  input [63:0]      l2data_bank_wdata,

  // l2data interface (out)
  output reg [63:0] l2bank_rdata);

  // 8B wide, 32KB, 64B line => 4096 entries
  reg [63:0] datamem [0:4095];

  // input latches
  reg        valid_in_r;
  reg        wen_r;
  reg [11:0] addr_r;
  reg [7:0]  wmask_r;
  reg [63:0] wdata_r;

  always @(posedge clk)
    if(rst)
      valid_in_r <= 0;
    else begin
      valid_in_r <= l2data_bank_valid;
      if(l2data_bank_valid) begin
        wen_r <= l2data_bank_wen;
        addr_r <= l2data_bank_addr;
        wmask_r <= l2data_bank_wmask;
        wdata_r <= l2data_bank_wdata;
      end
    end

  integer i;
  always @(posedge clk)
    if(valid_in_r)
      if(~wen_r)
        l2bank_rdata <= datamem[addr_r];
      else for(i = 0; i < 8; i=i+1)
        if(wmask_r[i])
          datamem[addr_r][i*8+:8] <= wdata_r[i*8+:8];

endmodule
