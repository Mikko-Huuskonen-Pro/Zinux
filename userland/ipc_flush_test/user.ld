/* userland/ipc_flush_test/user.ld — ipc flush -testin muistikartta @ 0xFFFFFFFF90088000 */

/* Ring 3 ipc flush -testi — pino heap-slot 109. */
ENTRY(_start)

SECTIONS
{
    /* Ipc flush -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90088000;

    /* Suoritettava koodi + merkkijonot. */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
        *(.ltext .ltext.*)
    }

    /* Vain-luku -data. */
    .rodata : {
        *(.rodata .rodata.*)
    }

    /* Alustettu data. */
    .data : {
        *(.data .data.*)
    }

    /* BSS omalle sivulle. */
    . = ALIGN(0x1000);
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
