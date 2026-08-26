/* linker.ld — Zinux kernelin muistikartta (Limine higher-half boot)          */
/* Jokainen osio dokumentoitu jälkipolvien lukemista varten.                  */

/* Kernelin sisääntulopiste — Limine hyppää tähän symboliin bootissa.           */
ENTRY(_start)

/* Higher-half kernelin virtuaalinen latausosoite (-2 GiB osoiteavaruudessa).   */
KERNEL_BASE = 0xFFFFFFFF80000000;

/* Program headerit — Limine vaatii .limine_requests erillisenä PT_LOAD:na.     */
PHDRS
{
    limine_requests PT_LOAD;
    text            PT_LOAD;
    rodata          PT_LOAD;
    data            PT_LOAD;
}

SECTIONS
{
    /* Kaikki sectionit sijoitetaan KERNEL_BASE:n jälkeen.                      */
    . = KERNEL_BASE;

    /* Limine request -taulukko — bootloader täyttää response-osoittimet.       */
    .limine_requests : {
        KEEP(*(.limine_requests_start))
        KEEP(*(.limine_requests))
        KEEP(*(.limine_requests_end))
    } :limine_requests

    /* Tasaus sivurajalle ennen suoritettavaa koodia.                             */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* .text — suoritettava konekoodi (funktiot, inline asm).                   */
    .text : {
        KEEP(*(.text.entry))
        *(.text .text.*)
    } :text

    /* Tasaus ennen vain-luku -dataa.                                            */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* .rodata — merkkijonot, vakiot, vtables.                                  */
    .rodata : {
        *(.rodata .rodata.*)
    } :rodata

    /* Tasaus ennen alustettua dataa.                                            */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* .data — alustettu muuttuja-data.                                         */
    .data : {
        *(.data .data.*)
    } :data

    /* Tasaus ennen BSS:ää.                                                     */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* .bss — nollattu data (varataan RAM, ei levytilaa).                        */
    .bss : {
        *(COMMON)
        *(.bss .bss.*)
    } :data

    /* /DISCARD/ — poista debug- ja kommenttiosiot lopullisesta ELF:stä.        */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
    }
}
