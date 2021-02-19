/* Default linker script, for normal executables */
/* Copyright (C) 2014-2020 Free Software Foundation, Inc.
   Copying and distribution of this script, with or without modification,
   are permitted in any medium without royalty provided the copyright
   notice and this notice are preserved.  */
OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  ROM (rx) : ORIGIN = 0x10000000, LENGTH = 256K
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 128M
}

SECTIONS
{
  .text : {
    KEEP (*(SORT_NONE(.init)))

    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(SORT(.text.sorted.*))
    *(.text .stub .text.* .gnu.linkonce.t.*)

    KEEP (*(SORT_NONE(.fini)))

    *(.eh_frame_hdr) *(.eh_frame_entry .eh_frame_entry.*)
    /* KEEP (*(.eh_frame)) *(.eh_frame.*) */
    /* *(.gcc_except_table .gcc_except_table.*) */
    /* *(.gnu_extab*) */

    *(.rodata .rodata.* .gnu.linkonce.r.*)
    *(.rodata1)

    . = ALIGN(8);
  } > ROM

  _etext = .;

  .data : AT(_etext) {
    _sdata = .;

    /* Exception handling  */
    KEEP (*(.eh_frame)) *(.eh_frame.*)
    *(.gnu_extab)
    *(.gcc_except_table .gcc_except_table.*)

    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array))
    PROVIDE_HIDDEN (__preinit_array_end = .);

    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
    PROVIDE_HIDDEN (__init_array_end = .);

    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
    KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
    PROVIDE_HIDDEN (__fini_array_end = .);

    /* gcc uses crtbegin.o to find the start of
       the constructors, so we make sure it is
       first.  Because this is a wildcard, it
       doesn't matter if the user does not
       actually link against crtbegin.o; the
       linker won't look for a file to match a
       wildcard.  The wildcard also means that it
       doesn't matter which directory crtbegin.o
       is in.  */
    KEEP (*crtbegin.o(.ctors))
    KEEP (*crtbegin?.o(.ctors))
    /* We don't want to include the .ctor section from
       the crtend.o file until after the sorted ctors.
       The .ctor section from the crtend file contains the
       end of ctors marker and it must be last */
    KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
    KEEP (*(SORT(.ctors.*)))
    KEEP (*(.ctors))

    KEEP (*crtbegin.o(.dtors))
    KEEP (*crtbegin?.o(.dtors))
    KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
    KEEP (*(SORT(.dtors.*)))
    KEEP (*(.dtors))

    __DATA_BEGIN__ = .;
    *(.data .data.* .gnu.linkonce.d.*)
    *(.data1)

    /* Thread Local Storage sections  */
    PROVIDE_HIDDEN (__tdata_start = .);
    *(.tdata .tdata.* .gnu.linkonce.td.*)
    *(.tdata1)

    /* We want the small data sections together, so single-instruction offsets
       can access them all, and initialized data all before uninitialized, so
       we can shorten the on-disk segment size.  */
    __SDATA_BEGIN__ = .;
    *(.sdata .sdata.* .gnu.linkonce.s.*)
    *(.sdata2 .sdata2.* .gnu.linkonce.s2.*)
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata .srodata.*)
  } > RAM

  _edata = .;

  .bss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.sbss2 .sbss2.* .gnu.linkonce.sb2.*)
    *(.scommon)

    *(.tbss .tbss.* .gnu.linkonce.tb.*) *(.tcommon)

    *(.bss .bss.* .gnu.linkonce.b.*)
    *(COMMON)
    __BSS_END__ = .;
  } > RAM

  _end = .;

  __global_pointer$ = MIN(__SDATA_BEGIN__ + 0x800,
                          MAX(__DATA_BEGIN__ + 0x800, __BSS_END__ - 0x800));

  _stack = ORIGIN(RAM) + LENGTH(RAM);

  . = 0x30000000;
  tohost = .;
  . += 8;
  fromhost = .;
}
