// SHF
/* verilator lint_off WIDTH */
/* verilator lint_off UNOPTFLAT */
module shf #(
  parameter W = 32,
  parameter RIGHT = 1
  )(
  input                  sgn,
  input [W-1:0]          a,
  input [$clog2(W)-1:0]  b,
  output [W-1:0]         c);
  
  localparam B = $clog2(W);
  wire [(W*3)-1:0] shf_acc [B:0];
 
  wire [W-1:0] oz = -(sgn & RIGHT & a[W-1]);
  assign shf_acc[0] = {oz, a, {W{1'b0}}};

  genvar i;
  generate
    if (RIGHT)
      for (i = 0; i < B; i = i + 1) begin : rshf_outer
        wire [W-1:0] shf_i;
        mux #(32, 2) rshf_mux (.sel(b[i]),
            .in({shf_acc[i][(W+(2**i)) +: W], shf_acc[i][W +: W]}),
            .out(shf_i));
        assign shf_acc[i+1] = {oz , shf_i, {W{1'b0}}};
      end
    else
      for (i = 0; i < B; i = i + 1) begin : lshf_outer
        wire [W-1:0] shf_i;
        mux #(32, 2) lshf_mux (.sel(b[i]),
            .in({shf_acc[i][(W-(2**i)) +: W], shf_acc[i][W +: W]}),
            .out(shf_i));
        assign shf_acc[i+1] = {oz, shf_i, {W{1'b0}}};
      end
  endgenerate
  
  assign c = shf_acc[B][W+:W]; 

endmodule
/* verilator lint_on UNOPTFLAT */
/* verilator lint_on WIDTH */
