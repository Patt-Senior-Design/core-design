#!/bin/bash

if [ $# -lt 2 ]; then
  echo "Usage: rungraph.sh <from node (default: 3)> <to node (default: 2)>"
fi

DIR=$(dirname $0)

# C arguments
FROM_NODE=$1
TO_NODE=$2

# Verilog arguments
FROM_NODE_VARG=""
TO_NODE_VARG=""
if [[ -n $FROM_NODE  &&  -n $TO_NODE ]]; then
  FROM_NODE_VARG="+from=$FROM_NODE"
  TO_NODE_VARG="+to=$TO_NODE"
fi


make -C $DIR || exit $?

# C Graph run 
./graph_test/graph $FROM_NODE $TO_NODE | tee graph.out
GRAPHPID=$!
if [ $? -eq 124 ]; then
  exit 1
fi

# Verilog run
TIMEOUT=10
timeout $TIMEOUT $DIR/top_bfs $FROM_NODE_VARG $TO_NODE_VARG
SIMPID=$!
if [ $? -eq 124 ]; then
  exit 1
fi


