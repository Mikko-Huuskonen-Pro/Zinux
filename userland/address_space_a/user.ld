/* userland/address_space_a/user.ld — sama VA kuin B (Vaihe 25) @ 0xFFFFFFFF90090000 */

ENTRY(_start)

SECTIONS
{
    . = 0xFFFFFFFF90090000;

    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    .rodata : {
        *(.rodata .rodata.*)
    }

    .data : {
        *(.data .data.*)
    }

    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
