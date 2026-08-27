/* userland/cap_get_type_test/user.ld — cap get type -testin muistikartta @ 0xFFFFFFFF90086000 */

/* Ring 3 cap get type -testi — pino heap-slot 108. */
ENTRY(_start)

SECTIONS
{
    /* Cap get type -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90086000;

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

    /* Kernel kirjoittaa slot + odotettu tyyppi ennen ring 3 -hyppyä. */
    . = ALIGN(0x1000);
    .capboot : {
        capGetTypeSlot = .;
        LONG(0);
        capGetTypeExpect = .;
        LONG(0);
    }
}
