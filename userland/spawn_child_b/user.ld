/* userland/spawn_child_b/user.ld — spawn-lapsi B @ 0xFFFFFFFF9008C000 */

/* Ring 3 spawn-lapsi B — erillinen LOAD-alue (slot 113 pino). */
ENTRY(_start)

SECTIONS
{
    /* Spawn-lapsi B virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF9008C000;

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
