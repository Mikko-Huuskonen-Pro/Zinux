/* userland/cap_test/user.ld — cap userland -testin muistikartta @ 0xFFFFFFFF90070000 */

/* Ring 3 cap-testi — parent cap slot 6, pino heap-slot 101. */
ENTRY(_start)

SECTIONS
{
    /* Cap-testin virtuaalinen latausosoite — erillään ipc/driver-ELF:stä. */
    . = 0xFFFFFFFF90070000;

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

    /* Kernel kirjoittaa parent capability-slotin ennen ring 3 -hyppyä. */
    . = ALIGN(0x1000);
    .capboot : {
        capParentSlot = .;
        LONG(0);
    }
}
