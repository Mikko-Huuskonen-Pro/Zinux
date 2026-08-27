/* userland/cap_create_test/user.ld — cap create -testin muistikartta @ 0xFFFFFFFF90080000 */

/* Ring 3 cap create -testi — pino heap-slot 102. */
ENTRY(_start)

SECTIONS
{
    /* Cap create -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90080000;

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
