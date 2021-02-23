SIM := iverilog
SIMOPTS := -g2001 -ctimescale -Wall -s test_bfs
SRCS_V := $(wildcard *.v)

SRCS_C := $(basename $(wildcard graph_test/*.c))
#OUTS_O := $(SRCS_C:.c=.o)

.PHONY: all clean

all: top_bfs $(SRCS_C)

top_bfs: $(SRCS_V) testbenches/test_bfs.v
	$(SIM) $(SIMOPTS) -o top_bfs $(SRCS_V) testbenches/test_bfs.v

%.o: %.c
	gcc $<

clean:
	@echo "Cleaning executables"
	@rm -f *.vcd top_bfs *.mem *.out *.o
