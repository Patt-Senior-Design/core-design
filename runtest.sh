#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: runtest.sh <test name>"
    exit 1
fi

DIR=$(dirname $0)
TEST=$1

HEXFILE=$DIR/tests/$TEST.hex
ELFFILE=$DIR/tests/$TEST.elf
LOGFILE=$DIR/tests/$TEST.log
DIFFFILE=$DIR/tests/$TEST.diff

make -C $DIR/tests || exit $?
make -C $DIR/behavioral || exit $?
make -C $DIR/plugins || exit $?

rm -f simtrace spiketrace

mkfifo simtrace
timeout 5 $DIR/behavioral/build/top +memfile=$HEXFILE +tracefile=simtrace +logfile=$LOGFILE &
SIMPID=$!

mkfifo spiketrace
timeout 5 spike --log-commits --isa=RV32IM \
        -m0x10000000:0x10000,0x20000000:0x400000,0x30000000:0x1000 \
        --extlib="$DIR/plugins/uart.so" --device=uart,0x30010000 \
        $ELFFILE 2> spiketrace &
SPIKEPID=$!

# ignore the lines from the spike boot rom
$DIR/checktrace.py > $DIFFFILE
DIFFSTATUS=$?

rm simtrace spiketrace

wait $SIMPID
if [ $? -eq 124 ]; then
    echo "iverilog timed out" >> $DIFFFILE
    DIFFSTATUS=1
fi

wait $SPIKEPID
if [ $? -eq 124 ]; then
    echo "spike timed out" >> $DIFFFILE
    DIFFSTATUS=1
fi

$DIR/checkmem.py $LOGFILE >> $DIFFFILE
if [ $? -ne 0 ]; then
    DIFFSTATUS=1
fi

head -n30 $DIFFFILE
exit $DIFFSTATUS
