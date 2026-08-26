/* userland/shell/user.ld — shell-prosessin muistikartta @ 0xFFFFFFFF90040000 */

/* Ring 3 shell — bss @ 0x42000, user-pino heap-slot 67 @ 0x43000. */
ENTRY(_start)

SECTIONS
{
    /* Shellin virtuaalinen latausosoite — higher-half 4K-sivut. */
    . = 0xFFFFFFFF90040000;

    /* Suoritettava koodi + merkkijonot (yksi PT_LOAD-sivu). */
    .text : {
        KEEP(*(.text._start))
        *(.text .text.*)
    }

    /* Vain-luku -data (eh_frame jne.). */
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
