MEMORY
{
    ROM (rx) : ORIGIN = 0, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 256M
}

SECTIONS
{
    .text : { *(.text) *(.text.*) } > ROM
    .rodata : { *(.rodata) *(.srodata) } > ROM
    . = ALIGN(4);
    _etext = .;

    .data : AT(_etext) {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.sdata)
        _edata = .;
    } > RAM
    __global_pointer$ = .;
    .bss : { *(.bss) *(COMMON) } > RAM
    _end = .;
}
