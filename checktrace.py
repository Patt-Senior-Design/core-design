#!/usr/bin/env python3

def main() -> int:
    with open("simtrace", "r") as simtrace, open("spiketrace", "r") as spiketrace:
        for i in range(5):
            spiketrace.readline()
        while True:
            simline = simtrace.readline()
            spikeline = spiketrace.readline()
            if simline == "":
                if spikeline == "":
                    return 0
                print("-"+spikeline, end="")
                return 1
            if spikeline == "":
                print("+"+simline, end="")
                return 1
            if simline != spikeline:
                print("-"+spikeline, end="")
                print("+"+simline, end="")
                return 1

if __name__ == "__main__":
    exit(main())
