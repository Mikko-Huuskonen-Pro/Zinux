/* userland/ipc_block_test/user.ld — ipc block -testin muistikartta @ 0xFFFFFFFF90090000 */

/* Ring 3 blocking recv -testi — pino heap-slot 103, boot-info @ 0x90091000. */
ENTRY(_start)

SECTIONS
{
    /* Ipc block -testin virtuaalinen latausosoite. */
    . = 0xFFFFFFFF90090000;

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

    /* Kernel kirjoittaa capability-slotin ennen ring 3 -hyppyä. */
    . = ALIGN(0x1000);
    .ipcboot : {
        ipcBlockSlot = .;
        LONG(0);
    }
}
