/* userland/spawn_cap_test/user.ld — spawn cap demo @ 0xFFFFFFFF90090F000 */

/* Ring 3 spawn cap -testi — pino heap-slot 120 (erillään cross_spawn). */
ENTRY(_start)

SECTIONS
{
    /* Spawn cap -testin virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF90092000;

    /* Suoritettava koodi (_start start.S:stä). */
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
