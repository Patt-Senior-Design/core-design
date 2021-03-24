#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: runspike.sh <args>"
    exit 1
fi

DIR=$(dirname $0)

exec spike --isa=RV32IM \
    -m0x10000000:0x1000000,0x20000000:0x8000000,0x30000000:0x1000 \
    --extlib="$DIR/plugins/uart.so" --device=uart,0x30010000 \
    --extension=hashset \
    "$@"
