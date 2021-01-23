#!/bin/sh

DIR=$(dirname $0)
TESTS="$(basename -s .s $DIR/tests/*.s) $(basename -s .c $DIR/tests/*.c)"
for TEST in $TESTS; do
    if [ $TEST = startup -o $TEST = stdlib ]; then continue; fi

    printf "%-16s" $TEST
    ./runtest.sh $TEST > /dev/null
    if [ $? -eq 0 ]; then
        echo "passed"
    else
        echo "failed"
    fi
done
