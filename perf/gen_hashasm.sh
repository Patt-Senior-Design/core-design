#!/bin/bash
DIR=$(dirname $0)
SEED_CT=$1

#if [ $# -lt 1 ]; then
#  echo "Usage: gen_hashasm.sh <number of seeded tests>"
#  exit 1
#fi

make -C $DIR/exec clean > /dev/null || exit $?
#for n in $(seq $SEED_CT); do
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -Wall -O2 -ffunction-sections \
                                     -fdata-sections  -S -o $DIR/exec/hashset.s $DIR/hashset.c
$DIR/replace_func.py $DIR/exec/fasthash.s $DIR/exec/hashset.s $DIR/findfast_new.S
#done

make -C $DIR/exec > /dev/null || exit $? 

echo "Generated perf executables"
