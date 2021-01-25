SIM := iverilog
ifeq ($(SIM),iverilog)
SIMOPTS := -g2001 -ctimescale -Wall -s top
else ifeq ($(SIM),vcs)
SIMOPTS := -full64 +v2k +warn=all -race=all -timescale=1ns/1ps -top top
else
$(error Unknown simulator $(SIM))
endif

SRCS := $(wildcard *.v)

.PHONY: all clean

all: build/top

build/top: $(SRCS) build/cpu.v
	$(SIM) $(SIMOPTS) -o build/top $(SRCS) build/cpu.v

build/cpu.v: $(SRCS) | build
	@rm -f build/cpu.v
	emacs -Q --batch --file=build/cpu.v --insert=../cpu.v.in --eval='(push ".." verilog-library-directories)' -f verilog-auto -f save-buffer

build:
	mkdir build

clean:
	@rm -rf csrc build *.vcd
