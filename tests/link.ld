ENTRY(_start)

MEMORY
{
    ROM (rx) : ORIGIN = 0x10000000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 4M
}

SECTIONS
{
    .text : { *(.text) *(.text.*) } > ROM
    .rodata : { *(.rodata) *(.srodata) } > ROM
    . = ALIGN(4);
    ._vector_table : { KEEP(*(._vector_table)) } > ROM
    _etext = .;

    .data : AT(_etext) {
        . = ALIGN(4);
        _sdata = .;
        *(.data) *(.data.*)
        *(.sdata) *(.sdata.*)
        _edata = .;
    } > RAM

    .bss : { *(.bss) *(COMMON) } > RAM
    _end = .;

    _stack = ORIGIN(RAM) + LENGTH(RAM);

    . = 0x30000000;
    tohost = .;
    . += 8;
    fromhost = .;
}
