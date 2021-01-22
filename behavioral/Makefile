SRCS := $(wildcard *.v)

.PHONY: all clean

all: build/top

build/top: $(SRCS) build/cpu.v
	iverilog -g2001 -ctimescale -Wall -s top -o build/top $(SRCS) build/cpu.v

build/cpu.v: $(SRCS) | build
	@rm -f build/cpu.v
	emacs -Q --batch --file=build/cpu.v --insert=../cpu.v.in --eval='(push ".." verilog-library-directories)' -f verilog-auto -f save-buffer

build:
	mkdir build

clean:
	@rm -rf build *.vcd
