/* userland/cross_spawn_ipc_child/user.ld — spawn-lapsi @ 0xFFFFFFFF90090000 */

/* Ring 3 cross-spawn IPC child — erillinen osoiteavaruus (Vaihe 25). */
ENTRY(_start)

SECTIONS
{
    /* Sama latausosoite kuin muilla spawn-lapsilla — eristetty PT per prosessi. */
    . = 0xFFFFFFFF90090000;

    /* Suoritettava koodi. */
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

    /* BSS. */
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
