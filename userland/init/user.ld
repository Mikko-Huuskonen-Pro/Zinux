/* userland/init/user.ld — init-prosessin muistikartta @ 0xFFFFFFFF90030000 */

/* Ring 3 init — erillinen LOAD-alue loader-testistä (slot 48). */
ENTRY(_start)

SECTIONS
{
    /* Init-prosessin virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF90030000;

    /* Suoritettava koodi (_start start.S:stä). */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    /* Vain-luku -data (init-viesti). */
    .rodata : {
        *(.rodata .rodata.*)
    }

    /* Alustettu data. */
    .data : {
        *(.data .data.*)
    }

    /* Nollattu BSS. */
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
