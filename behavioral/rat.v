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
  input [4:0]   rob_ret_rd,
  input [31:0]  rob_ret_result);

  reg[31:0] comm_val_rs1;
  reg[31:0] comm_val_rs2;
  reg[6:0] tag_rs1;
  reg[6:0] tag_rs2;
  reg[6:0] tag_wb;
  reg[31:0] spec_val_rs1;
  reg[31:0] spec_val_rs2;
  reg forward_cur_rs1;
  reg forward_cur_rs2;
  reg forward_prev_rs1;
  reg forward_prev_rs2;

  reg wb_write;
  // Old CDB value
  reg wb_prev_write;
  reg[31:0] wb_prev_result;
  reg[6:0] wb_prev_robid;
  reg[4:0] wb_prev_rd; 

  reg valid_rs1;
  reg valid_rs2;
  reg committed_rs1;
  reg committed_rs2;

  reg ld_tag;
  reg ld_spec_val;
 
  reg[31:0] rat_valid;
  reg[31:0] rat_committed;
 
  reg[31:0] rat_comm_val[31:0];
  reg[6:0] rat_tag[31:0];
  reg[31:0] rat_spec_val[31:0];
  /*
  sram_rat #(.DATAW(32)) rat_comm_val (
    .clk(clk),
    .rst(rst),
    .rd_en1(rename_rat_valid),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(comm_val_rs1),
    .rd_en2(rename_rat_valid),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(comm_val_rs2),
    .wr_en(rob_ret_valid),
    .wr_addr(rob_ret_rd),
    .wr_data(rob_ret_result));
  
  sram_rat #(.DATAW(7)) rat_tag (
    .clk(clk),
    .rst(rst),
    .rd_en1(rename_rat_valid),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(tag_rs1),
    .rd_en2(rename_rat_valid),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(tag_rs2),
    .wr_en(ld_tag),
    .wr_addr(rename_rat_rd[4:0]),
    .wr_data(rename_rat_robid[6:0]));
  
  sram_rat #(.DATAW(32)) rat_spec_val (
    .clk(clk),
    .rst(rst),
    .rd_en1(rename_rat_valid),
    .rd_addr1(rename_rat_rs1),
    .rd_data1(spec_val_rs1),
    .rd_en2(rename_rat_valid),
    .rd_addr2(rename_rat_rs2),
    .rd_data2(spec_val_rs2),
    .wr_en(ld_spec_val),
    .wr_addr(wb_rd[4:0]),
    .wr_data(wb_result));
 */

  always @(posedge clk) begin
    // SRAM Behavioral
    if (rename_rat_valid) begin
      comm_val_rs1 <= rename_rat_rs1 ? rat_comm_val[rename_rat_rs1] : 0;
      comm_val_rs2 <= rename_rat_rs2 ? rat_comm_val[rename_rat_rs2] : 0;
      tag_rs1 <= rat_tag[rename_rat_rs1];
      tag_rs2 <= rat_tag[rename_rat_rs2];
      tag_wb <= rat_tag[wb_rd[4:0]];
      spec_val_rs1 <= (ld_spec_val & (rename_rat_rs1 == wb_prev_rd)) ?
                        wb_prev_result : (rename_rat_rs1 ? rat_spec_val[rename_rat_rs1] : 0);
      spec_val_rs2 <= (ld_spec_val & (rename_rat_rs2 == wb_prev_rd)) ?
                        wb_prev_result : (rename_rat_rs2 ? rat_spec_val[rename_rat_rs2] : 0);
    end
    if (rob_ret_valid)
      rat_comm_val[rob_ret_rd] <= rob_ret_result;
    if (ld_tag)
      rat_tag[rename_rat_rd[4:0]] <= rename_rat_robid[6:0];
    if (ld_spec_val)
      rat_spec_val[wb_rd[4:0]] <= wb_prev_result;
  end

  always @(posedge clk) begin
    if (rst | rob_flush) begin
      rat_valid <= 32'hFFFFFFFF;
      rat_committed <= 32'hFFFFFFFF;
    end 
    if (rename_rat_valid) begin
      // Read control bits: Forward if insn in decode and 2nd wb cycle
      valid_rs1 <= (wb_prev_write & (rename_rat_rs1 == wb_prev_rd)) ?
                    1'b1 : rat_valid[rename_rat_rs1];
      valid_rs2 <= (wb_prev_write & (rename_rat_rs2 == wb_prev_rd)) ?
                    1'b1 : rat_valid[rename_rat_rs2];
      committed_rs1 <= rat_committed[rename_rat_rs1];
      committed_rs2 <= rat_committed[rename_rat_rs2];
    end
    // Write control bits
    if (ld_spec_val)
      rat_valid[wb_prev_rd[4:0]] <= 1;
    if (rename_rat_valid & (~rename_rat_rd[5])) begin
      rat_valid[rename_rat_rd[4:0]] <= 0;
      rat_committed[rename_rat_rd[4:0]] <= 0;
    end  
  end

  // Save CDB values
  always @(posedge clk) begin
    if (rst | rob_flush)
      wb_prev_write <= 1'b0;
    wb_prev_write <= wb_write;
    wb_prev_robid <= wb_robid[6:0];
    wb_prev_result <= wb_result;
    wb_prev_rd <= wb_rd[4:0];
  end

  always @(*) begin
    ld_tag = rename_rat_valid & (~rename_rat_rd[5]);
    wb_write = wb_valid & (~wb_error) & (~wb_rd[5]);
    ld_spec_val = wb_prev_write & (wb_prev_robid == tag_wb);
    // Forward value: Prev and Cur CDB val
    forward_prev_rs1 = wb_prev_write & (wb_prev_robid == tag_rs1);
    forward_prev_rs2 = wb_prev_write & (wb_prev_robid == tag_rs2);
    forward_cur_rs1 = wb_write & (wb_robid[6:0] == tag_rs1);
    forward_cur_rs2 = wb_write & (wb_robid[6:0] == tag_rs2);
    rat_rs1_valid = forward_cur_rs1 | forward_prev_rs1 | valid_rs1;
    rat_rs2_valid = forward_cur_rs2 | forward_prev_rs2 | valid_rs2;
    casez({committed_rs1, valid_rs1})
      2'b00: rat_rs1_tagval = (forward_prev_rs1 ? wb_prev_result : 
                                (forward_cur_rs1 ? wb_result : tag_rs1));
      2'b01: rat_rs1_tagval = spec_val_rs1;
      2'b11: rat_rs1_tagval = comm_val_rs1;
      default: rat_rs1_tagval = 32'bx;
    endcase
    casez({committed_rs2, valid_rs2})
      2'b00: rat_rs2_tagval = (forward_prev_rs2 ? wb_prev_result :
                                (forward_cur_rs2 ? wb_result : tag_rs2));
      2'b01: rat_rs2_tagval = spec_val_rs2;
      2'b11: rat_rs2_tagval = comm_val_rs2;
      default: rat_rs1_tagval = 32'bx;
    endcase
  end
  
endmodule
