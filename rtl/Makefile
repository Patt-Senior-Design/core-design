SIM := vcs
DRAMSIM := $(shell pwd)/../dramsim
SRCS := $(wildcard lib/*.v) $(wildcard src/*.v) src/bfs/bfs_core.v src/bfs/bfs_queue.v src/bfs/queue_main.v src/bfs/queue_out.v

ifeq ($(SIM),vcs)
SRCS += $(DRAMSIM)/dramsim_vpi.cc
SIMOPTS := -full64 -v2005 +warn=all +race=all -timescale=1ns/1ps -top top
SIMOPTS += +vpi -CFLAGS "-I$(DRAMSIM)/DRAMsim3/src"
SIMOPTS += -LDLFLAGS "-L$(DRAMSIM)/DRAMsim3 -Wl,--push-state,--no-as-needed,--whole-archive -l:libdramsim3.a -Wl,--pop-state"
SIMOPTS += -P $(DRAMSIM)/pli.tab
SIMOPTS += -o build/top

build/top: $(SRCS) build/cpu.v $(DRAMSIM)/DRAMsim3/libdramsim3.a
	$(SIM) $(SIMOPTS) $(SRCS) build/cpu.v
else ifeq ($(SIM),verilator)
SRCS += src/top.cc $(DRAMSIM)/dramsim_verilator.cc
SIMOPTS := --cc --exe --Mdir build --top top
SIMOPTS += -CFLAGS "-I$(DRAMSIM) -I$(DRAMSIM)/DRAMsim3/src -march=native"
SIMOPTS += -LDFLAGS "-L$(DRAMSIM)/DRAMsim3 -Wl,--push-state,--no-as-needed,--whole-archive -l:libdramsim3.a -Wl,--pop-state"
SIMOPTS += --trace-fst --trace-threads 1 --trace-max-array 128
SIMOPTS += -o top

build/top: $(SRCS) build/cpu.v $(DRAMSIM)/DRAMsim3/libdramsim3.a
	$(SIM) $(SIMOPTS) $(SRCS) build/cpu.v
	$(MAKE) -C build -f Vtop.mk OPT_SLOW=-O2 OPT_FAST=-O3 OPT_GLOBAL=-O3
else
$(error Unknown simulator $(SIM))
endif

.PHONY: all clean

all: build/top

build/%.v: $(SRCS) %.v.in | build
	./auto.sh $*.v

$(DRAMSIM)/DRAMsim3/libdramsim3.a:
	$(MAKE) -C $(DRAMSIM)/DRAMsim3

build:
	mkdir build

clean:
	@rm -rf csrc build *.vcd
