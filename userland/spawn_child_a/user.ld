/* userland/spawn_child_a/user.ld — spawn-lapsi A @ 0xFFFFFFFF9008B000 */

/* Ring 3 spawn-lapsi A — erillinen LOAD-alue (slot 112 pino). */
ENTRY(_start)

SECTIONS
{
    /* Spawn-lapsi A virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF9008B000;

    /* Suoritettava koodi (_start start.S:stä). */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    /* Vain-luku -data (spawn-viesti). */
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
