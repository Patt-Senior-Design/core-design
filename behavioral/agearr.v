// age array
module agearr #(
  parameter HEIGHT = 16,
  parameter WIDTH = 16,
  parameter OLDER = 1
  )(
  input                   clk,
  input                   rst,

  input                   set_row_valid,
  input [HEIGHT-1:0]      set_row_sel,

  input                   clear_col_valid,
  input [WIDTH-1:0]       clear_col_sel,

  input [HEIGHT-1:0]      row_sel,
  output reg [HEIGHT-1:0] col_sel);

  // row-major
  reg [WIDTH-1:0] matrix [0:HEIGHT-1];

  integer i, j, k;
  always @(posedge clk)
    if(rst)
      for(i = 0; i < HEIGHT; i=i+1)
        matrix[i] <= 0;
    else begin
      if(set_row_valid)
        for(i = 0; i < HEIGHT; i=i+1)
          if(set_row_sel[i])
            // set row bits
            matrix[i] <= {WIDTH{1'b1}};

      if(clear_col_valid)
        for(j = 0; j < WIDTH; j=j+1)
          if(clear_col_sel[j])
            for(k = 0; k < HEIGHT; k=k+1)
              // clear column bits (and detect undefined inputs)
              matrix[k][j] <= (set_row_valid & set_row_sel[k]) ? 1'bx : 0;
    end

  integer l;
  always @(*) begin
    col_sel = 0;
    for(l = 0; l < HEIGHT; l=l+1)
      if(row_sel[l])
        col_sel = col_sel | matrix[l];
  end

endmodule
