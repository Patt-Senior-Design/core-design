// Defines for common primitives to make rtl code cleaner

/* FLOPS */
/* R - specify reset, NR - no reset.       Default: reset = rst
   S - specify set, default no set.        Default: set = 0
   E - specify explicit enable/in signals. Default: enable = 1
*/

`define FLOP(SIG_OUT, WIDTH, SIG_IN) \
    \
    wire [``WIDTH-1``:0] ``SIG_OUT``; \
    flop #(.width(``WIDTH``)) ``SIG_OUT``_flop ( \
        .clk (clk), \
        .set (1'b0), \
        .rst (rst), \
        .enable (1'b1), \
        .d (``SIG_IN``), \
        .q (``SIG_OUT``));

`define FLOP_RS(SIG_OUT, WIDTH, RST, SET) \
    \
    wire [``WIDTH-1``:0] ``SIG_OUT``; \
    flop #(.width(``WIDTH``)) ``SIG_OUT``_flop ( \
        .clk (clk), \
        .set (``SET``), \
        .rst (``RST``), \
        .enable (1'b0), \
        .d (``WIDTH``'b0), \
        .q (``SIG_OUT``));

`define FLOP_E(SIG_OUT, WIDTH, SIG_EN, SIG_IN) \
    \
    wire [``WIDTH-1``:0] ``SIG_OUT``; \
    flop #(.width(``WIDTH``)) ``SIG_OUT``_flop ( \
        .clk (clk), \
        .set (1'b0), \
        .rst (rst), \
        .enable (``SIG_EN``), \
        .d (``SIG_IN``), \
        .q (``SIG_OUT``));

`define FLOP_NRE(SIG_OUT, WIDTH, SIG_EN, SIG_IN) \
    \
    wire [``WIDTH-1``:0] ``SIG_OUT``; \
    flop #(.width(``WIDTH``)) ``SIG_OUT``_flop ( \
        .clk (clk), \
        .set (1'b0), \
        .rst (1'b0), \
        .enable (``SIG_EN``), \
        .d (``SIG_IN``), \
        .q (``SIG_OUT``));

`define FLOP_ERS(SIG_OUT, WIDTH, SIG_EN, SIG_IN, RST, SET) \
    \
    wire [``WIDTH-1``:0] ``SIG_OUT``; \
    flop #(.width(``WIDTH``)) ``SIG_OUT``_flop ( \
        .clk (clk), \
        .set (``SET``), \
        .rst (``RST``), \
        .enable (``SIG_EN``), \
        .d (``SIG_IN``), \
        .q (``SIG_OUT``));


/* ============================================ */

/* COMBINATIONAL LOGIC */

`define MUX2X1(SIG_OUT, WIDTH, SEL, IN0, IN1) \
    \
    mux2x1 #(.W(``WIDTH``)) ``SIG_OUT``_mux ( \
        .sel (``SEL``), \
        .in0 (``IN0``), \
        .in1 (``IN1``), \
        .out (``SIG_OUT``));

`define MUX4X1(SIG_OUT, WIDTH, SEL, IN0, IN1, IN2, IN3) \
    \
    mux4x1 #(.W(``WIDTH``)) ``SIG_OUT``_mux ( \
        .sel (``SEL``), \
        .in0 (``IN0``), \
        .in1 (``IN1``), \
        .in2 (``IN2``), \
        .in3 (``IN3``), \
        .out (``SIG_OUT``));

`define ADD(WIDTH, SIG_OUT, SIG_OP1, SIG_OP2) \
    \
    rca #(.W(``WIDTH``)) ``SIG_OUT``_adder ( \
        .sub (1'b0), \
        .a (``SIG_OP1``), \
        .b (``SIG_OP2``), \
        .c (``SIG_OUT``)); \

`define SUB(WIDTH, SIG_OUT, SIG_OP1, SIG_OP2) \
    \
    rca #(.W(``WIDTH``)) ``SIG_OUT``_adder ( \
        .sub (1'b1), \
        .a (``SIG_OP1``), \
        .b (``SIG_OP2``), \
        .c (``SIG_OUT``)); \


