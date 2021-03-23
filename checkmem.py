#!/usr/bin/env python3

import sys

RAMBASE = 0x20000000//4
RAMSIZE = 0x8000000//4

# two categories of entry:
# 1. read (lw/lh/lb/lhu/lbu/lbcmp)
# 2. write (sw/sh/sb)
class MemoryEntry:
    def __init__(self, line: int, time: int, category: str, addr: int, wdata: int = None):
        self.line = line
        self.time = time
        self.category = category
        self.addr = addr
        self.rdata = None
        self.wdata = wdata

def getLoadResult(entry: MemoryEntry, memValue: int) -> int:
    memValue >>= (entry.addr & 3) * 8
    if entry.category == "lh":
        memValue = ((memValue & 0x7fff) - (memValue & 0x8000)) & 0xffffffff
    elif entry.category == "lb":
        memValue = ((memValue & 0x7f) - (memValue & 0x80)) & 0xffffffff
    elif entry.category == "lhu":
        memValue = memValue & 0xffff
    elif entry.category == "lbu":
        memValue = memValue & 0xff
    return memValue

def getStoreResult(entry: MemoryEntry, memValue: int) -> int:
    shift = (entry.addr & 3) * 8
    regValue = entry.wdata << shift
    if entry.category == "sw":
        return regValue
    if entry.category == "sh":
        mask = 0xffff << shift
        return (memValue & ~mask) | (regValue & mask)
    if entry.category == "sb":
        mask = 0xff << shift
        return (memValue & ~mask) | (regValue & mask)
    return None

def getCmpResult(entry: MemoryEntry, ram: list) -> int:
    base = (entry.addr // 4) & ~1
    byte = entry.wdata & 0xff
    result = 0
    for i in range(8):
        word = ram[base-RAMBASE]
        for j in range(4):
            result = (result >> 1) | (0x80000000 if ((word & 0xff) == byte) else 0)
            word >>= 8
        base += 1
    return result

class MemoryTrace:
    def __init__(self, logfile: str):
        self.logfile = logfile
    def parse(self) -> bool:
        self.entries = []
        lsqids = [None] * 16
        linenum = 1
        success = True
        with open(self.logfile, "r") as f:
            for line in f:
                fields = line.split()
                time = int(fields[0])
                category = fields[1]
                if category[0] == "l":
                    # lw/lh/lb/lhu/lbu/lbcmp (read request)
                    addr = int(fields[2], 16)
                    if category == "lbcmp":
                        op2 = int(fields[3], 16)
                        lsqid = int(fields[4])
                    else:
                        op2 = None
                        lsqid = int(fields[3])
                    lsqids[lsqid] = len(self.entries)
                    self.entries.append(MemoryEntry(linenum, time, category, addr, op2))
                    if (category[1] == "h" and (addr & 1)) or (category[1] == "w" and (addr & 3)) or (category == "lbcmp" and (addr & 7)):
                        print("WARN: misaligned {} at line {} ({}ns)".format(category, linenum, time))
                elif category[0] == "s":
                    # sw/sh/sb (write)
                    addr = int(fields[2], 16)
                    wdata = int(fields[3], 16)
                    self.entries.append(MemoryEntry(linenum, time, category, addr, wdata))
                    if (category[1] == "h" and (addr & 1)) or (category[1] == "w" and (addr & 3)):
                        print("WARN: misaligned {} at line {} ({}ns)".format(category, linenum, time))
                elif category == "resp":
                    # read response
                    lsqid = int(fields[2])
                    rdata = int(fields[3], 16)
                    if lsqids[lsqid] is None:
                        print("FAIL checkmem at line {} ({}ns): orphaned response".format(linenum, time))
                        success = False
                    else:
                        self.entries[lsqids[lsqid]].rdata = rdata
                        lsqids[lsqid] = None
                elif category == "flush":
                    for index in lsqids:
                        if index is not None:
                            self.entries[index].rdata = "<flushed>"
                    lsqids = [None] * 16
                linenum += 1
        for index in lsqids:
            if index:
                entry = self.entries[index]
                print("FAIL checkmem at line {} ({}ns): orphaned request".format(entry.line, entry.time))
                success = False
        return success
    def check(self) -> tuple:
        memory = [0] * RAMSIZE
        for entry in self.entries:
            if entry.category[0] == "l":
                if entry.rdata == "<flushed>":
                    continue
                memAddr = (entry.addr // 4) - RAMBASE
                if memAddr < 0 or memAddr >= len(memory):
                    #print("WARN: not checking line {}, addr {:08x} not in RAM".format(entry.line, entry.addr))
                    continue
                memValue = memory[memAddr]
                if entry.category == "lbcmp":
                    result = getCmpResult(entry, memory)
                else:
                    result = getLoadResult(entry, memValue)
                if entry.rdata != result:
                    return (entry,result)
            elif entry.category[0] == "s":
                memAddr = (entry.addr // 4) - RAMBASE
                if memAddr < 0 or memAddr >= len(memory):
                    #print("WARN: not checking line {}, addr {:08x} not in RAM".format(entry.line, entry.addr))
                    continue
                memValue = memory[memAddr]
                memory[memAddr] = getStoreResult(entry, memValue)
        return None

def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: checklog.py <logfile>")
        exit(1)
    memtrace = MemoryTrace(sys.argv[1])
    if not memtrace.parse():
        return 1
    mismatch = memtrace.check()
    if mismatch:
        entry = mismatch[0]
        if entry.rdata is not None:
            gotVal = "{:08x}".format(entry.rdata)
        else:
            gotVal = "<no response>"
        expectedVal = mismatch[1]
        print("FAIL checkmem at line {} ({}ns): {} {:08x} (got {}, expected {:08x})".format(
            entry.line, entry.time, entry.category, entry.addr, gotVal, expectedVal))
        return 1
    print("PASS checkmem")
    return 0

if __name__ == "__main__":
    exit(main())
