#!/bin/sh

DIR=$(dirname $0)
MODEL=${1:-behavioral}
echo "Running $MODEL model"
TESTS="$(basename -s .s $DIR/tests/*.s) $(basename -s .c $DIR/tests/*.c) $(basename -s .cpp $DIR/tests/*.cpp)"
for TEST in $TESTS; do
    if [ $TEST = startup -o $TEST = stdlib ]; then continue; fi

    printf "%-16s" $TEST
    $DIR/runtest.sh $TEST $MODEL > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "passed"
    else
        echo "failed"
    fi
done
