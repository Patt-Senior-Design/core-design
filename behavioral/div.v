// 32 x 32 divider
module div(
  input         clk,
  input         rst,

  input         req,
  input [1:0]   op,
  input [31:0]  op1,
  input [31:0]  op2,

  output        done,
  output [31:0] result,
  input         stall);

  localparam
    INIT = 2'b00,
    PROG = 2'b01,
    PROG_FINAL = 2'b10;

  // Divider state
  reg [4:0]  d_iter;
  reg [63:0] d_acc;
  reg [1:0]  d_state;

  // Dividend
  wire dvd_sgn;
  assign dvd_sgn = op1[31] & ~op[0];

  wire [31:0] dvd;
  assign dvd = dvd_sgn ? (~op1 + 1) : op1;

  // Divisor
  wire dsor_sgn;
  assign dsor_sgn = op2[31] & ~op[0];

  wire [33:0] dsor;
  assign dsor = dsor_sgn ? {2'b11, op2} : ({2'b11, ~op2} + 1);

  // Remainder (1)
  wire [33:0] ptl_rem;
  assign ptl_rem = {1'b0,d_acc[63:31]};

  // Compare
  wire [33:0] cmp_res;
  assign cmp_res = ptl_rem + dsor;

  // Remainder (2)
  wire [31:0] ptl_rem_n;
  assign ptl_rem_n = cmp_res[33] ? ptl_rem[31:0] : cmp_res[31:0];

  // Shift
  wire [31:0] d_shf;
  assign d_shf = {d_acc[30:0],~cmp_res[33]};

  // Result
  reg [31:0] div_result;
  assign div_result = op[1] ? d_acc[63:32] : d_acc[31:0];

  // Outputs
  assign done = d_state == PROG_FINAL;
  assign result = (dvd_sgn ^ (~op[1] & dsor_sgn)) ? (~div_result + 1) : div_result;

  // State machine
  reg [4:0]  d_iter_c;
  reg [63:0] d_acc_c;
  reg [1:0]  d_next_state;
  always @(posedge clk) begin
    d_iter <= d_iter_c;
    d_acc <= d_acc_c;
    d_state <= rst ? INIT : d_next_state;
  end

  always @(*) begin
    d_acc_c = 0;
    d_iter_c = 0;
    d_next_state = d_state;
    case(d_state)
      INIT: begin
        // Output init
        d_acc_c = {32'b0,dvd};
        if(req)
          d_next_state = PROG;
      end

      PROG: begin
        // Output
        d_acc_c = {ptl_rem_n,d_shf};
        d_iter_c = d_iter - 1;
        if(d_iter == 1)
          d_next_state = PROG_FINAL;
      end

      PROG_FINAL: begin
        d_acc_c = d_acc;
        if(~stall)
          d_next_state = INIT;
      end

      default:
        d_next_state = INIT;
    endcase
  end

endmodule
