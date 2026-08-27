/* userland/cap_get_rights_test/user.ld — cap get rights -testin muistikartta @ 0xFFFFFFFF90084000 */

/* Ring 3 cap get rights -testi — pino heap-slot 107. */
ENTRY(_start)

SECTIONS
{
    /* Cap get rights -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90084000;

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

    /* BSS omalle sivulle. */
    . = ALIGN(0x1000);
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    }

    /* Kernel kirjoittaa slot + mask ennen ring 3 -hyppyä. */
    . = ALIGN(0x1000);
    .capboot : {
        capGetRightsSlot = .;
        LONG(0);
        capGetRightsMask = .;
        LONG(0);
    }
}
