// 32 x 32 multiplier
module mul(
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

  // Multiplier state
  reg        x0;
  reg        inv;
  reg [3:0]  iter;
  reg [65:0] acc;
  reg [1:0]  state;

  // Sign extension
  wire op1_sgn;
  assign op1_sgn = op1[31] & (op[1] ^ op[0]);

  wire [65:0] acc_se;
  assign acc_se = $signed(acc) >>> 2;

  // Booth encoding
  wire x2, x1;
  wire single, double, neg;
  assign {x2, x1} = acc[1:0];
  assign single = x1 ^ x0;
  assign double = ((~x2 & x1 & x0) | (x2 & (~x1) & (~x0)));
  assign neg = x2;

  // Partial product
  reg [33:0] ptl_prod_i;
  always @(*)
    if(state == PROG_FINAL)
      ptl_prod_i = (x0 & ~(~op[1] & op[0])) ? {2'b0, op1} : 0;
    else begin
      case(1)
        single: ptl_prod_i = { {2{op1_sgn}}, op1 }; // Sign-extend Op
        double: ptl_prod_i = { op1_sgn, op1, 1'b0 };
        default: ptl_prod_i = 0;
      endcase
      if(neg)
        ptl_prod_i = ~ptl_prod_i;
    end

  wire [35:0] ptl_prod; // Extra MSB, 2 extra bits for negation correction
  assign ptl_prod = {ptl_prod_i,1'b0,inv};

  // Output
  wire [63:0] mul_result;
  assign mul_result = acc_se[63:0] + {ptl_prod[33:0], 30'b0};

  assign done = state == PROG_FINAL;
  assign result = |op[1:0] ? mul_result[63:32] : mul_result[31:0];

  // State machine
  reg        x0_c;
  reg        inv_c;
  reg [3:0]  iter_c;
  reg [65:0] acc_c;
  reg [1:0]  next_state;
  always @(posedge clk) begin
    x0 <= x0_c;
    inv <= inv_c;
    iter <= iter_c;
    acc <= acc_c;
    state <= rst ? INIT : next_state;
  end

  always @(*) begin
    x0_c = 0;
    inv_c = 0;
    iter_c = 0;
    acc_c = 0;
    next_state = state;
    case(state)
      INIT: begin
        acc_c = {34'b0,op2};
        if(req)
          next_state = PROG;
      end

      PROG: begin
        x0_c = acc[1];
        inv_c = neg;
        iter_c = iter - 1;
        acc_c = acc_se + {ptl_prod, 30'b0};
        if(iter == 1)
          next_state = PROG_FINAL;
      end

      PROG_FINAL: begin
        inv_c = inv;
        acc_c = acc;
        if(~stall)
          next_state = INIT;
      end

      default:
        next_state = INIT;
    endcase
  end

endmodule
