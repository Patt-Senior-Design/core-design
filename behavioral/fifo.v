// first-in, first-out (FIFO) queue
module fifo #(
  parameter WIDTH = 8,
  parameter DEPTH = 8,

  // local parameters
  parameter LDEPTH = $clog2(DEPTH)
  )(
  input              clk,
  input              rst,

  input              wr_valid,
  output             wr_ready,
  input [WIDTH-1:0]  wr_data,

  output             rd_valid,
  input              rd_ready,
  output [WIDTH-1:0] rd_data);

  // head, tail: counters used for checking full/empty conditions
  // head_oh, tail_oh: one-hot shift registers used for select signals
  // head_pol, tail_pol: parity bits used to distinguish between empty and full
  reg [LDEPTH-1:0] head, tail;
  reg [DEPTH-1:0]  head_oh, tail_oh;
  reg              head_pol, tail_pol;

  reg [WIDTH-1:0]  data [0:DEPTH-1];

  wire full, empty;
  assign full = (head == tail) & (head_pol != tail_pol);
  assign empty = (head == tail) & (head_pol == tail_pol);

  wire wr_beat, rd_beat;
  assign wr_ready = ~full | rd_beat;
  assign rd_valid = ~empty;

  assign wr_beat = wr_valid & wr_ready;
  assign rd_beat = rd_valid & rd_ready;

  always @(posedge clk)
    if(rst) begin
      tail <= 0;
      tail_oh <= 1;
      tail_pol <= 0;
    end else if(wr_beat) begin
      tail <= tail + 1;
      tail_oh <= {tail_oh[DEPTH-2:0],tail_oh[DEPTH-1]};
      if(tail_oh[DEPTH-1])
        tail_pol <= ~tail_pol;
    end

  always @(posedge clk)
    if(rst) begin
      head <= 0;
      head_oh <= 1;
      head_pol <= 0;
    end else if(rd_beat) begin
      head <= head + 1;
      head_oh <= {head_oh[DEPTH-2:0],head_oh[DEPTH-1]};
      if(head_oh[DEPTH-1])
        head_pol <= ~head_pol;
    end

  // in rtl/structural impl, *_oh will be used instead
  assign rd_data = data[head];
  always @(posedge clk)
    if(wr_beat)
      data[tail] <= wr_data;

endmodule
