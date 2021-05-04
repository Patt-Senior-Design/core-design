module sext #(parameter OUT, parameter IN)(input [IN-1:0] in, output [OUT-1:0] out);
    assign out = {{(OUT-IN){in[IN-1]}}, in};
endmodule
