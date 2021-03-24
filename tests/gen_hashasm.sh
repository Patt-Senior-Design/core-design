#!/bin/sh
DIR=$(dirname $0)
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -Wall -O2 -ffunction-sections -fdata-sections -S -o $DIR/hashset.S $DIR/hashset.c
$DIR/replace_func.py $DIR/fast_hash.s $DIR/hashset.S $DIR/findfast.S
make -C $DIR || exit $?
