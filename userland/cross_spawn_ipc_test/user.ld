/* userland/cross_spawn_ipc_test/user.ld — parent @ 0xFFFFFFFF90091000 */

/* Ring 3 cross-spawn IPC parent — pino heap-slot 120. */
ENTRY(_start)

SECTIONS
{
    /* Parent ELF virtuaalinen latausosoite — erillään muista testeistä. */
    . = 0xFFFFFFFF90091000;

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
