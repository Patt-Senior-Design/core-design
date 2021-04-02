SIM := verilator
DRAMSIM := $(shell pwd)/../dramsim
SRCS := $(wildcard *.v) bfs/bfs_core.v bfs/bfs_queue.v bfs/queue_main.v bfs/queue_out.v

ifeq ($(SIM),vcs)
SRCS += $(DRAMSIM)/dramsim_vpi.cc
SIMOPTS := -full64 +v2k +warn=all +race=all -timescale=1ns/1ps -top top
SIMOPTS += +vpi -CFLAGS "-I$(DRAMSIM)/DRAMsim3/src"
SIMOPTS += -LDLFLAGS "-L$(DRAMSIM)/DRAMsim3 -Wl,--push-state,--no-as-needed,--whole-archive -l:libdramsim3.a -Wl,--pop-state"
SIMOPTS += -P $(DRAMSIM)/pli.tab
SIMOPTS += -o build/top_$(SIM)
TARGET := build/top_$(SIM)
else ifeq ($(SIM),verilator)
SRCS += $(shell pwd)/top.cc $(DRAMSIM)/dramsim_verilator.cc
SIMOPTS := --cc --exe --build --Mdir build/verilator --top top -Wno-fatal
SIMOPTS += -CFLAGS "-I$(DRAMSIM) -I$(DRAMSIM)/DRAMsim3/src -march=native"
SIMOPTS += -LDFLAGS "-L$(DRAMSIM)/DRAMsim3 -Wl,--push-state,--no-as-needed,--whole-archive -l:libdramsim3.a -Wl,--pop-state"
SIMOPTS += -o top_$(SIM)
TARGET := build/verilator/top_$(SIM)
else
$(error Unknown simulator $(SIM))
endif

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRCS) build/cpu.v $(DRAMSIM)/DRAMsim3/libdramsim3.a
	$(SIM) $(SIMOPTS) $(SRCS) build/cpu.v

build/%.v: $(SRCS) %.v.in | build
	./auto.sh $*.v

$(DRAMSIM)/DRAMsim3/libdramsim3.a:
	$(MAKE) -C $(DRAMSIM)/DRAMsim3

build:
	mkdir build

clean:
	@rm -rf csrc build *.vcd
