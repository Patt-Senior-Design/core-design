TARGET := $(shell ../scripts/detect-riscv-prefix.sh)
AS := $(TARGET)-as
CC := $(TARGET)-gcc
OBJCOPY := $(TARGET)-objcopy
OBJDUMP := $(TARGET)-objdump

ASFLAGS := -march=rv32im -mabi=ilp32
CFLAGS := -march=rv32im -mabi=ilp32 -Wall -O2 -ffunction-sections -fdata-sections
LFLAGS := -march=rv32im -mabi=ilp32 -nostartfiles -Wl,--gc-sections

SRCS_S := $(filter-out startup.s, $(wildcard *.s))
SRCS_C := $(filter-out stdlib.c, $(wildcard *.c))
OUTS_ELF := $(SRCS_S:.s=.elf) $(SRCS_C:.c=.elf)
OUTS_HEX := $(OUTS_ELF:.elf=.hex)
OUTS_DIS := $(OUTS_ELF:.elf=.dis)

.PHONY: all clean

all: $(OUTS_ELF) $(OUTS_HEX) $(OUTS_DIS)

%.elf: %.o startup.o stdlib.o link.ld
	$(CC) $(LFLAGS) -Tlink.ld -o $*.elf startup.o $< stdlib.o

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.xxd: %.bin
	xxd -e -c4 -g4 $< $@

%.hex: %.xxd
	cut -d' ' -f2 $< > $@

%.dis: %.elf
	$(OBJDUMP) -d -Mnumeric -Mno-aliases $< > $@

clean:
	@rm -f *.elf *.hex *.xxd *.o *.bin *.diff
