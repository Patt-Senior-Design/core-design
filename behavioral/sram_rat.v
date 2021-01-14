module sram_rat #(
  parameter ADDRW = 5,
  parameter DATAW = 1
  )(
  input                  clk,
  input                  rst,
  input                  rd_en1,
  input [ADDRW-1:0]      rd_addr1,
  output reg [DATAW-1:0] rd_data1,
  
  input                  rd_en2,
  input [ADDRW-1:0]      rd_addr2,
  output reg [DATAW-1:0] rd_data2,

  input                  wr_en,
  input [ADDRW-1:0]      wr_addr,
  input [DATAW-1:0]      wr_data
  );

  reg             rd_en1_r;
  reg [ADDRW-1:0] rd_addr1_r;
  reg [DATAW-1:0] rd_data1_r;
  
  reg             rd_en2_r;
  reg [ADDRW-1:0] rd_addr2_r;
  reg [DATAW-1:0] rd_data2_r;

  reg             wr_en_r;
  reg [ADDRW-1:0] wr_addr_r;
  reg [DATAW-1:0] wr_data_r;

  reg [DATAW-1:0] memory [0:(1<<ADDRW)-1];

  always @(posedge clk) begin
    if (rst) begin
      rd_en1_r <= 0;
      rd_en2_r <= 0;
      wr_en_r <= 0;
    end
    else begin
      rd_en1_r <= rd_en1;
      rd_addr1_r <= rd_addr1;
      rd_data1_r <= rd_data1;
      rd_en2_r <= rd_en2;
      rd_addr2_r <= rd_addr2;
      rd_data2_r <= rd_data2;
      wr_en_r <= wr_en;
      wr_addr_r <= wr_addr;
      wr_data_r <= wr_data;
    end
  end

  always @(negedge clk) begin
    if (rd_en1_r)
      rd_data1 <= memory[rd_addr1_r];
    if (rd_en2_r)
      rd_data2 <= memory[rd_addr2_r];
    if (wr_en_r)
      memory[wr_addr_r] <= wr_data_r;
  end
endmodule

  
  
