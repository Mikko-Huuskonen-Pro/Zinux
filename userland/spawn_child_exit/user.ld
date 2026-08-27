/* userland/spawn_child_exit/user.ld — spawn-lapsi exit @ 0xFFFFFFFF9008F000 */

/* Ring 3 spawn-lapsi exit — erillinen LOAD-alue (slot 115 pino). */
ENTRY(_start)

SECTIONS
{
    /* Spawn-lapsi exit virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF9008F000;

    /* Suoritettava koodi (_start start.S:stä). */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    /* Vain-luku -data. */
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
