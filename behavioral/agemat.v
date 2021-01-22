// age matrix
module agemat #(
  parameter WIDTH = 16,
  parameter OLDEST = 1
  )(
  input                  clk,
  input                  rst,

  input                  insert_valid,
  input [WIDTH-1:0]      insert_sel,

  input [WIDTH-1:0]      req,
  output reg             grant_valid,
  output reg [WIDTH-1:0] grant);

  // column-major for faster simulation
  reg [WIDTH-1:0] matrix [0:WIDTH-1];

  integer i, j;
  always @(posedge clk)
    if(rst)
      for(i = 0; i < WIDTH; i=i+1)
        matrix[i] <= 0;
    else if(insert_valid)
      for(i = 0; i < WIDTH; i=i+1)
        if(insert_sel[i])
          for(j = 0; j < WIDTH; j=j+1)
            if(j != i) begin
              // set row bits, clear column bits
              matrix[j][i] <= 1;
              matrix[i][j] <= 0;
            end

  integer k;
  always @(*) begin
    grant = req;
    for(k = 0; k < WIDTH; k=k+1)
      if(req[k])
        grant = grant & (OLDEST ? ~matrix[k] : matrix[k]);
    grant_valid = |grant;
  end

endmodule
