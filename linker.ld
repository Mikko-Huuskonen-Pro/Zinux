/* linker.ld — Zinux kernelin muistikartta (Limine higher-half boot)          */
/* Jokainen osio dokumentoitu jälkipolvien lukemista varten.                  */

/* Kernelin sisääntulopiste — Limine hyppää tähän symboliin bootissa.           */
ENTRY(_start)

/* Higher-half kernelin virtuaalinen latausosoite (-2 GiB osoiteavaruudessa).   */
KERNEL_BASE = 0xFFFFFFFF80000000;

SECTIONS
{
    /* Kaikki sectionit sijoitetaan KERNEL_BASE:n jälkeen.                      */
    . = KERNEL_BASE;

    /* .text — suoritettava konekoodi (funktiot, inline asm).                   */
    .text : {
        KEEP(*(.text.entry))   /* Entry point ensimmäiseksi — kriittinen bootille */
        *(.text .text.*)
    } :text

    /* .rodata — vain luku -data (merkkijonot, vakiot, vtables).                */
    .rodata : {
        *(.rodata .rodata.*)
    } :rodata

    /* .data — alustettu muuttuja-data (kopioitu mukaan ELF:stä).               */
    .data : {
        *(.data .data.*)
    } :data

    /* .bss — nollattu data (varataan tilaa, ei vie levytilaa).                 */
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    } :bss

    /* /DISCARD/ — heitä pois debug- ja comment-sectionit lopullisesta ELF:stä. */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
    }
}
