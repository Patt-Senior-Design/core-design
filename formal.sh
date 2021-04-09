#!/bin/sh

if [ -z "$(which fm_shell)" ]; then
    echo "fm_shell not found, please 'module unload' any existing synopsys environments and 'module load synopsys/2019'"
    exit 1
fi

exec fm_shell -overwrite -file formal.tcl
