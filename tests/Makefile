TARGET := riscv64-unknown-elf
AS := $(TARGET)-as
LD := $(TARGET)-ld
OBJCOPY := $(TARGET)-objcopy
OBJDUMP := $(TARGET)-objdump

ASFLAGS := -march=rv32im -mabi=ilp32

SRCS_S := $(wildcard *.s)
OUTS_ELF := $(SRCS_S:.s=.elf)
OUTS_HEX := $(OUTS_ELF:.elf=.hex)
OUTS_DIS := $(OUTS_ELF:.elf=.dis)

.PHONY: all clean

all: $(OUTS_HEX) $(OUTS_DIS)

%.elf %.o: %.s link.ld
	$(AS) $(ASFLAGS) -o $*.o $<
	$(LD) -b elf32-littleriscv -Tlink.ld -o $*.elf $*.o

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.xxd: %.bin
	xxd -e -c4 -g4 $< $@

%.hex: %.xxd
	cut -d' ' -f2 $< > $@

%.dis: %.elf
	$(OBJDUMP) -d -Mnumeric -Mno-aliases $< > $@

clean:
	@rm -f *.elf *.hex *.xxd *.o *.bin
