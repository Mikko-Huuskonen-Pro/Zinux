/* userland/cap_get_resource_test/user.ld — cap get resource -testin muistikartta @ 0xFFFFFFFF90089000 */

/* Ring 3 cap get resource -testi — pino heap-slot 110. */
ENTRY(_start)

SECTIONS
{
    /* Cap get resource -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90089000;

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

    /* Kernel kirjoittaa slot + odotettu port_id ennen ring 3 -hyppyä. */
    . = ALIGN(0x1000);
    .capboot : {
        capGetResourceSlot = .;
        LONG(0);
        capGetResourceExpect = .;
        LONG(0);
    }
}
