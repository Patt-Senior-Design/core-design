#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: runtest.sh <test name>"
    exit 1
fi

DIR=$(dirname $0)
TEST=$1

HEXFILE=$DIR/tests/$TEST.hex
ELFFILE=$DIR/tests/$TEST.elf
DIFFFILE=$DIR/tests/$TEST.diff

make -C $DIR/tests || exit $?
make -C $DIR/behavioral || exit $?

mkfifo simtrace
timeout 5 $DIR/behavioral/build/top +memfile=$HEXFILE +tracefile=simtrace &
SIMPID=$!

mkfifo spiketrace
timeout 5 spike --log-commits --isa=RV32IM \
        -m0x10000000:0x10000,0x20000000:0x400000,0x30000000:0x1000 \
        $ELFFILE 2> spiketrace &
SPIKEPID=$!

# ignore the lines from the spike boot rom
diff -u -I '^core   0: 3 0x000010' spiketrace simtrace > $DIFFFILE
DIFFSTATUS=$?

rm simtrace spiketrace

wait $SIMPID
if [ $? -eq 124 ]; then
    echo "iverilog timed out" >> $DIFFFILE
    exit 1
fi

wait $SPIKEPID
if [ $? -eq 124 ]; then
    echo "spike timed out" >> $DIFFFILE
    exit 1
fi

cat $DIFFFILE
exit $DIFFSTATUS
