// register alias table
module rat(
  input         clk,
  input         rst,

  // rename interface
  input         rename_rat_valid,
  input [5:0]   rename_rat_rd,
  input [7:0]   rename_rat_robid,
  input [4:0]   rename_rat_rs1,
  input [4:0]   rename_rat_rs2,
  output reg       rat_rs1_valid,
  output reg[31:0] rat_rs1_tagval,
  output reg       rat_rs2_valid,
  output reg[31:0] rat_rs2_tagval,

  // wb interface
  input         wb_valid,
  input         wb_error,
  input [7:0]   wb_robid,
  input [5:0]   wb_rd,
  input [31:0]  wb_result,

  // rob interface
  input         rob_flush,
  input         rob_ret_valid,
  input [5:0]   rob_ret_rd,
  input [31:0]  rob_ret_result);

  wire[31:0] comm_val_rs1;
  wire[31:0] comm_val_rs2;
  wire[6:0] tag_rs1;
  wire[6:0] tag_rs2;
  wire[31:0] spec_val_rs1;
  wire[31:0] spec_val_rs2;
  reg forward_rs1;
  reg forward_rs2;

  reg valid_rs1;
  reg valid_rs2;
  reg committed_rs1;
  reg committed_rs2;

  reg ld_comm_val;
  reg ld_tag;
  reg ld_spec_val;
  reg ld_valid;
  reg ld_committed;
 
  reg[31:0] rat_valid;
  reg[31:0] rat_committed;
  
  sram_rat #(.DATAW(32)) rat_comm_val (
    .clk(clk),
    .rst(rst),
    .rd_en1(1'b1),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(comm_val_rs1),
    .rd_en2(1'b1),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(comm_val_rs2),
    .wr_en(ld_comm_val),
    .wr_addr(rob_ret_rd[4:0]),
    .wr_data(rob_ret_result));
  
  sram_rat #(.DATAW(7)) rat_tag (
    .clk(clk),
    .rst(rst),
    .rd_en1(1'b1),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(tag_rs1),
    .rd_en2(1'b1),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(tag_rs2),
    .wr_en(ld_tag),
    .wr_addr(rename_rat_rd[4:0]),
    .wr_data(rename_rat_robid[6:0]));
  
  sram_rat #(.DATAW(32)) rat_spec_val (
    .clk(clk),
    .rst(rst),
    .rd_en1(1'b1),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(spec_val_rs1),
    .rd_en2(1'b1),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(spec_val_rs2),
    .wr_en(ld_spec_val),
    .wr_addr(wb_rd[4:0]),
    .wr_data(wb_result));
 

  always @(posedge clk) begin
    if (rst) begin
      rat_valid <= 32'hFFFFFFFF;
      rat_committed <= 32'hFFFFFFFF;
    end 
    // Write control bits
    if (wb_valid) 
      rat_valid[wb_rd[4:0]] <= 1;
    if (rob_ret_valid)
      rat_committed[rob_ret_rd[4:0]] <= 1;
    if (rename_rat_valid) begin
      rat_valid[rename_rat_rd[4:0]] <= 0;
      rat_committed[rename_rat_rd[4:0]] <= 0;
    end  
    // Read control bits
    valid_rs1 <= rat_valid[rename_rat_rs1];
    valid_rs2 <= rat_valid[rename_rat_rs2];
    committed_rs1 <= rat_committed[rename_rat_rs1];
    committed_rs2 <= rat_committed[rename_rat_rs2];
  end

  always @(*) begin
    ld_tag = rename_rat_valid & (~rename_rat_rd[5]);
    ld_spec_val = wb_valid & (~wb_error) & (~wb_rd[5]);
    ld_comm_val = rob_ret_valid & (~rob_ret_rd[5]);
    // Forward value
    forward_rs1 = ld_spec_val & (wb_result[4:0] == rename_rat_rs1);
    forward_rs2 = ld_spec_val & (wb_result[4:0] == rename_rat_rs2);
    rat_rs1_valid = forward_rs1 | valid_rs1;
    rat_rs2_valid = forward_rs2 | valid_rs2;
    rat_rs1_tagval = rat_rs1_valid ? (forward_rs1 ? wb_result : spec_val_rs1) : tag_rs1;
    rat_rs2_tagval = rat_rs2_valid ? (forward_rs2 ? wb_result : spec_val_rs2) : tag_rs2;
  end
  
endmodule
