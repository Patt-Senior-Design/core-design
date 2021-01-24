// register alias table
module rat(
  input             clk,
  input             rst,

  // rename interface
  input [4:0]       rename_rs1,
  input [4:0]       rename_rs2,
  input             rename_alloc,
  input [4:0]       rename_rd,
  input [6:0]       rename_robid,
  output            rat_rs1_valid,
  output reg [31:0] rat_rs1_tagval,
  output            rat_rs2_valid,
  output reg [31:0] rat_rs2_tagval,

  // wb interface
  input             wb_valid,
  input             wb_error,
  input [6:0]       wb_robid,
  input [5:0]       wb_rd,
  input [31:0]      wb_result,

  // rob interface
  input             rob_flush,
  input             rob_ret_valid,
  input [4:0]       rob_ret_rd,
  input [31:0]      rob_ret_result);

  reg [31:0] rat_valid;
  reg [31:0] rat_committed;
  reg [31:0] rat_comm_val [31:0];
  reg [31:0] rat_spec_val [31:0];
  reg [6:0]  rat_tag [31:0];

  reg        valid_rs1, valid_rs2;
  reg        committed_rs1, committed_rs2;
  reg [31:0] comm_val_rs1, comm_val_rs2;
  reg [31:0] spec_val_rs1, spec_val_rs2;
  reg [6:0]  tag_rs1, tag_rs2, tag_wb;

  wire wb_write;
  assign wb_write = wb_valid & ~wb_error & ~wb_rd[5] & (wb_robid == tag_wb);

  wire fwd_rs1, fwd_rs2;
  assign fwd_rs1 = wb_write & (wb_rd[4:0] == rename_rs1);
  assign fwd_rs2 = wb_write & (wb_rd[4:0] == rename_rs2);

  // flag store read
  always @(*) begin
    valid_rs1 = rat_valid[rename_rs1];
    committed_rs1 = rat_committed[rename_rs1];

    valid_rs2 = rat_valid[rename_rs2];
    committed_rs2 = rat_committed[rename_rs2];
  end
  // flag store write
  always @(posedge clk) begin
    // if wb_rd == rename_rd, clear has precedence over set
    if(wb_write)
      rat_valid[wb_rd[4:0]] <= 1;
    if(rename_alloc) begin
      rat_valid[rename_rd] <= 0;
      rat_committed[rename_rd] <= 0;
    end

    if(rst | rob_flush) begin
      rat_valid <= 32'hFFFFFFFF;
      rat_committed <= 32'hFFFFFFFF;
    end
  end

  // committed data read
  always @(*) begin
    comm_val_rs1 = rat_comm_val[rename_rs1];
    comm_val_rs2 = rat_comm_val[rename_rs2];
  end
  // committed data write
  always @(posedge clk)
    if(rob_ret_valid)
      rat_comm_val[rob_ret_rd] <= rob_ret_result;

  // speculative data read
  always @(*) begin
    spec_val_rs1 = rat_spec_val[rename_rs1];
    spec_val_rs2 = rat_spec_val[rename_rs2];
  end
  // speculative data write
  always @(posedge clk)
    if(wb_write)
      rat_spec_val[wb_rd[4:0]] <= wb_result;

  // tag store read
  always @(*) begin
    tag_rs1 = rat_tag[rename_rs1];
    tag_rs2 = rat_tag[rename_rs2];
    tag_wb = rat_tag[wb_rd[4:0]];
  end

  // tag store write
  always @(posedge clk)
    if(rename_alloc)
      rat_tag[rename_rd] <= rename_robid;

  assign rat_rs1_valid = valid_rs1 | fwd_rs1;
  assign rat_rs2_valid = valid_rs2 | fwd_rs2;

  always @(*) begin
    if(fwd_rs1)
      rat_rs1_tagval = wb_result;
    else if(rename_rs1 == 0)
      rat_rs1_tagval = 0;
    else if(committed_rs1)
      rat_rs1_tagval = comm_val_rs1;
    else if(valid_rs1)
      rat_rs1_tagval = spec_val_rs1;
    else
      rat_rs1_tagval = tag_rs1;

    if(fwd_rs2)
      rat_rs2_tagval = wb_result;
    else if(rename_rs2 == 0)
      rat_rs2_tagval = 0;
    else if(committed_rs2)
      rat_rs2_tagval = comm_val_rs2;
    else if(valid_rs2)
      rat_rs2_tagval = spec_val_rs2;
    else
      rat_rs2_tagval = tag_rs2;
  end
  
endmodule
