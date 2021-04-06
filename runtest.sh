#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: runtest.sh <test name> <model: rtl/behavioral(default)"
    exit 1
fi

DIR=$(dirname $0)
TEST=$1
MODEL=${2:-behavioral}

DRAMCFG=$DIR/dramsim/DDR4_4Gb_x16_2666_2.ini
HEXFILE=$DIR/tests/$TEST.hex
ELFFILE=$DIR/tests/$TEST.elf
LOGFILE=$DIR/tests/$TEST.log
UARTFILE=$DIR/tests/$TEST.out

make -C $DIR/tests || exit $?
make -C $DIR/$MODEL || exit $?

rm -f simtrace

TIMEOUT=100000

mkfifo simtrace
timeout $TIMEOUT $DIR/$MODEL/build/top +dramcfg=$DRAMCFG +memfile=$HEXFILE +tracefile=simtrace +uartfile=$UARTFILE +logfile=$LOGFILE &
SIMPID=$!

timeout $TIMEOUT $DIR/runspike.sh --log-commits --cosim=simtrace $ELFFILE 2>/dev/null &
SPIKEPID=$!

ERROR=0

wait $SIMPID
if [ $? -eq 124 ]; then
    echo "ERROR: rtl timed out"
    ERROR=1
fi

wait $SPIKEPID; SPIKESTATUS=$?
if [ $SPIKESTATUS -eq 124 ]; then
    echo "ERROR: spike timed out"
    ERROR=1
elif [ $SPIKESTATUS -ne 0 ]; then
    echo "ERROR: spike exited with non-zero status"
    ERROR=1
fi

rm -f simtrace
$DIR/checkmem.py $LOGFILE
if [ $? -ne 0 ]; then
    ERROR=1
fi

if [ $ERROR -ne 0 ]; then
    echo "TEST FAILED"
fi

exit $ERROR
