SIM := iverilog
SIMOPTS := -g2001 -Wall -s test_bfs
SRCS_V := $(filter-out $(wildcard test*), $(wildcard *.v))

SRCS_C := $(basename $(wildcard *.c))
OUTS_O := $(SRCS_C:.c=.o)

.PHONY: all clean

all: top_bfs $(OUTS_O)

top_bfs: $(SRCS_V) test_bfs.v
	$(SIM) $(SIMOPTS) -o top_bfs $(SRCS_V) test_bfs.v

%.o: %.c
	gcc $<

clean:
	@echo "Cleaning executables"
	@rm -f *.vcd top_bfs *.mem *.out *.o
