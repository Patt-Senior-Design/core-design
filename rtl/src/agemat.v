// age matrix
module agemat #(
  parameter SIZE = 16
  )(
  input             clk,
  input             rst,

  input             insert_valid,
  input [SIZE-1:0]  insert_sel,

  input [SIZE-1:0]  req,
  output            grant_valid,
  output [SIZE-1:0] grant);

  // column-major for faster simulation
  wire [SIZE-1:0] matrix [0:SIZE-1];

  wire [SIZE-1:0] insert_en = {SIZE{insert_valid}} & insert_sel;

  genvar col, row;
  generate
    for(row = 0; row < SIZE; row=row+1)
      for(col = 0; col < SIZE; col=col+1)
        if(row != col)
          flop matrix_r(
            .clk(clk),
            .rst(insert_en[col] | rst),
            .set(insert_en[row]),
            .enable(1'b0),
            .d(1'b0),
            .q(matrix[col][row]));
  endgenerate

  /*verilator lint_off UNOPTFLAT*/
  wire [SIZE-1:0] steps [0:SIZE];
  assign steps[0] = req;

  genvar i;
  generate
    for(i = 0; i < SIZE; i=i+1)
      assign steps[i+1] = steps[i] & ({SIZE{~req[i]}} | ~matrix[i]);
  endgenerate
  /*verilator lint_on UNOPTFLAT*/

  assign grant = steps[SIZE];
  assign grant_valid = |grant;

endmodule
