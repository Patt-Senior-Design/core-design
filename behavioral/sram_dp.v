module sram_dp(
  parameter ADDRW = 8;
  parameter DATAW = 8;
  )(
  input                  clk,

  input                  rd_en,
  input [ADDRW-1:0]      rd_addr,
  output reg [DATAW-1:0] rd_data,

  input                  wr_en,
  input [ADDRW-1:0]      wr_addr,
  input [DATAW-1:0]      wr_data);

  reg             rd_en_r;
  reg [ADDRW-1:0] rd_addr_r;
  reg [DATAW-1:0] rd_data_r;
  reg             wr_en_r;
  reg [ADDRW-1:0] wr_addr_r;
  reg [DATAW-1:0] wr_data_r;
  reg [DATAW-1:0] mem [0:(1<<ADDRW)-1];

  always @(posedge clk) begin
    rd_en_r <= rd_en;
    rd_addr_r <= rd_addr;
    wr_en_r <= wr_en;
    wr_addr_r <= wr_addr;
    wr_data_r <= wr_data;
  end

  always @(negedge clk) begin
    if(rd_en_r)
      rd_data <= mem[rd_addr_r];
    if(wr_en_r)
      mem[wr_addr_r] <= wr_data_r;
  end

endmodule
