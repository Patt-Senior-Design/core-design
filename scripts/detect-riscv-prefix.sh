#!/bin/sh
RISCV64_PREFIX=riscv64-elf
if ! command -v "$RISCV64_PREFIX-gcc" &> /dev/null
then
    RISCV64_PREFIX=riscv64-unknown-elf
fi
echo $RISCV64_PREFIX
