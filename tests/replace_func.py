#!/usr/bin/env python3
import sys

def main(a1, a2, a3) -> int:
  with open(a1, "w") as dest_code, open(a2, "r") as src_code, open(a3, "r") as find_code:
    src_line = src_code.readline()
    replace = 0
    ct = 0
    while src_line:
      ct = ct +1
      if src_line.startswith('findNode:'): # Replace function
        find_func = find_code.readlines()
        dest_code.writelines(find_func)
        replace = 1
        #print("Found start ", replace)
      if '.-findNode' in src_line:
        replace = 0
        #print("Found end", replace)
      if not replace:
        dest_code.write(src_line)
        #print("Continue", replace)

      src_line = src_code.readline()
    
    print("Done")

if __name__ == '__main__':
  argc = len(sys.argv)
  if argc != 4:
    print("Usage: replace_func.py <output-asm> <source-asm> <function-asm>")
    exit(1)

  exit(main(*sys.argv[1:]))
  
