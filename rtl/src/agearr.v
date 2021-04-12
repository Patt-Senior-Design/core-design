// age array
module agearr #(
  parameter HEIGHT = 16,
  parameter WIDTH = 16
  )(
  input               clk,
  input               rst,

  input               set_row_valid,
  input [HEIGHT-1:0]  set_row_sel,

  input               clear_col_valid,
  input [WIDTH-1:0]   clear_col_sel,

  input [HEIGHT-1:0]  row_sel,
  output [HEIGHT-1:0] col_sel);

  wire [WIDTH-1:0] matrix [0:HEIGHT-1];

  wire [HEIGHT-1:0] set_row_en = {HEIGHT{set_row_valid}} & set_row_sel;
  wire [WIDTH-1:0] clear_col_en = {WIDTH{clear_col_valid}} & clear_col_sel;

  genvar row, col;
  generate
    for(row = 0; row < HEIGHT; row=row+1)
      for(col = 0; col < WIDTH; col=col+1)
        flop matrix_r(
          .clk(clk),
          .rst(clear_col_en[col] | rst),
          .set(set_row_en[row]),
          .enable(1'b0),
          .d(1'b0),
          .q(matrix[row][col]));
  endgenerate

  /*verilator lint_off UNOPTFLAT*/
  wire [WIDTH-1:0] steps [0:HEIGHT];
  assign steps[0] = 0;

  genvar i;
  generate
    for(i = 0; i < HEIGHT; i=i+1)
      assign steps[i+1] = steps[i] | ({WIDTH{row_sel[i]}} & matrix[i]);
  endgenerate
  /*verilator lint_on UNOPTFLAT*/

  assign col_sel = steps[HEIGHT];

endmodule
