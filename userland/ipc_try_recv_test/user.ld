/* userland/ipc_try_recv_test/user.ld — ipc try recv -testin muistikartta @ 0xFFFFFFFF90082000 */

/* Ring 3 ipc try recv -testi — pino heap-slot 105. */
ENTRY(_start)

SECTIONS
{
    /* Ipc try recv -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90082000;

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
