/* userland/ipc_queue_capacity_test/user.ld — ipc queue capacity -testin muistikartta @ 0xFFFFFFFF9008A000 */

/* Ring 3 ipc queue capacity -testi — pino heap-slot 111. */
ENTRY(_start)

SECTIONS
{
    /* Ipc queue capacity -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF9008A000;

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
