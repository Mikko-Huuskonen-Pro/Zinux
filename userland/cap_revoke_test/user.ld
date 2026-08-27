/* userland/cap_revoke_test/user.ld — cap revoke -testin muistikartta @ 0xFFFFFFFF90081000 */

/* Ring 3 cap revoke -testi — pino heap-slot 104. */
ENTRY(_start)

SECTIONS
{
    /* Cap revoke -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90081000;

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
}
