/* userland/ipc_pending_test/user.ld — ipc pending -testin muistikartta @ 0xFFFFFFFF90083000 */

/* Ring 3 ipc pending -testi — pino heap-slot 106. */
ENTRY(_start)

SECTIONS
{
    /* Ipc pending -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90083000;

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
