SIM := vcs
DRAMSIM := $(shell pwd)/../dramsim

ifeq ($(SIM),iverilog)
SIMOPTS := -g2001 -ctimescale -Wall -s top
else ifeq ($(SIM),vcs)
SIMOPTS := -full64 +v2k +warn=all +race=all -timescale=1ns/1ps -top top
SIMOPTS += +vpi -CFLAGS "-I$(DRAMSIM)/DRAMsim3/src"
SIMOPTS += -LDLFLAGS "-L$(DRAMSIM)/DRAMsim3 -Wl,--push-state,--no-as-needed,--whole-archive -l:libdramsim3.a -Wl,--pop-state"
SIMOPTS += -P $(DRAMSIM)/pli.tab
else
$(error Unknown simulator $(SIM))
endif

SRCS := $(wildcard *.v)

.PHONY: all clean

all: build/top

build/top: $(SRCS) build/cpu.v $(DRAMSIM)/dramsim_vpi.cc $(DRAMSIM)/DRAMsim3/libdramsim3.a
	$(SIM) $(SIMOPTS) -o build/top $^

build/cpu.v: $(SRCS) cpu.v.in | build
	@rm -f build/cpu.v
	emacs -Q --batch --file=build/cpu.v --insert=../cpu.v.in --eval='(push ".." verilog-library-directories)' -f verilog-auto -f save-buffer

$(DRAMSIM)/DRAMsim3/libdramsim3.a:
	$(MAKE) -C $(DRAMSIM)/DRAMsim3

build:
	mkdir build

clean:
	@rm -rf csrc build *.vcd
