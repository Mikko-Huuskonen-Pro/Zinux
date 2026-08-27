/* userland/cross_ipc_test/user.ld — cross-IPC testin muistikartta @ 0xFFFFFFFF9008E000 */

/* Ring 3 cross-IPC — rooli @ 0x9008D000, pino heap-slot 114. */
ENTRY(_start)

SECTIONS
{
    /* Cross-IPC-testin virtuaalinen latausosoite — erillään spawn-ELF:istä. */
    . = 0xFFFFFFFF9008E000;

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

    /* BSS omalle sivulle — loader remap ei saa ylikirjoittaa .text-sivua. */
    . = ALIGN(0x1000);
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
