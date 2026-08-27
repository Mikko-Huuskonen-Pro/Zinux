/* user.ld — freestanding käyttäjäohjelman muistikartta (ET_EXEC @ 0x400000) */
/* Loader-testi: yksi PT_LOAD-segmentti, ring 3 SYSCALL.                          */

/* Sisääntulopiste start.S:stä. */
ENTRY(_start)

SECTIONS
{
    /* Kiinteä virtuaalinen latausosoite — higher-half 4K-sivut (ei Limine huge). */
    . = 0xFFFFFFFF90020000;

    /* Suoritettava koodi. */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    /* Vain-luku -data (viestimerkkijonot). */
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
