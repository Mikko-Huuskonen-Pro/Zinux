/* userland/drivers/user.ld — ajuritestin muistikartta @ 0xFFFFFFFF90050000 */

/* Ring 3 ajuritesti — bss omalla sivulla, pino heap-slot 83. */
ENTRY(_start)

SECTIONS
{
    /* Ajuritestin virtuaalinen latausosoite — erillään shell/init-ELF:stä. */
    . = 0xFFFFFFFF90050000;

    /* Suoritettava koodi + merkkijonot. */
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

    /* BSS omalle sivulle — loader remap ei saa ylikirjoittaa .text-sivua. */
    . = ALIGN(0x1000);
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }
}
