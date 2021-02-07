TARGET := $(shell ../scripts/detect-riscv-prefix.sh)
AS := $(TARGET)-as
CC := $(TARGET)-gcc
CXX := $(TARGET)-g++
OBJCOPY := $(TARGET)-objcopy
OBJDUMP := $(TARGET)-objdump

ASFLAGS := -march=rv32im -mabi=ilp32
CFLAGS := -march=rv32im -mabi=ilp32 -Wall -O2 -ffunction-sections -fdata-sections
CXXFLAGS := -march=rv32im -mabi=ilp32 -Wall -O2 -ffunction-sections -fdata-sections
LFLAGS := -march=rv32im -mabi=ilp32 -nostartfiles -Wl,--gc-sections

SRCS_S := $(filter-out startup.s, $(wildcard *.s))
SRCS_C := $(filter-out stdlib.c, $(wildcard *.c))
SRCS_CXX := $(wildcard *.cpp)
OUTS_O := $(SRCS_S:.s=.o) $(SRCS_C:.c=.o) $(SRCS_CXX:.cpp=.o)
OUTS_ELF := $(OUTS_O:.o=.elf)
OUTS_HEX := $(OUTS_O:.o=.hex)
OUTS_DIS := $(OUTS_O:.o=.dis)

.PHONY: all clean

all: $(OUTS_O) $(OUTS_ELF) $(OUTS_HEX) $(OUTS_DIS) startup.o stdlib.o

%.elf: %.o startup.o stdlib.o link.ld
	$(CXX) $(LFLAGS) -Tlink.ld -o $*.elf startup.o $< stdlib.o

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.xxd: %.bin
	xxd -e -c4 -g4 $< $@

%.hex: %.xxd
	cut -d' ' -f2 $< > $@

%.dis: %.elf
	$(OBJDUMP) -d -Mnumeric -Mno-aliases $< > $@

clean:
	@rm -f *.elf *.hex *.xxd *.o *.bin *.diff *.dis *.log
