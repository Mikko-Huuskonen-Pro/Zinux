// Interaktiivinen shell — prompt, sys_read, help-komento (Vaihe 5.3).
.global _start

// Kaikki koodi ja merkkijonot samassa .text-segmentissä — loader ei saa ylikirjoittaa sivua.
.section .text

_start:
    // sys_write(1, prompt, 7) — tulosta "zinux> ".
    mov $1, %rax
    // fd = stdout (UART).
    mov $1, %rdi
    // Prompt heti koodin perässä (sama PT_LOAD-sivu).
    lea prompt(%rip), %rsi
    // Seitsemän tavua "zinux> ".
    mov $7, %rdx
    // Siirry kerneliin SYSCALL:lla.
    syscall
    // sys_read(0, line_buf, 128) — lue injektoitu "help\n".
    mov $11, %rax
    // fd = stdin (rengas + UART).
    xor %rdi, %rdi
    // Puskuri erillisessä BSS-sivussa (user.ld ALIGN 0x1000).
    lea line_buf(%rip), %rsi
    // Enintään 128 tavua per rivi.
    mov $128, %rdx
    // Blokkaava luku kunnes newline.
    syscall
    // Vertaa rivin alku "help" (neljä merkkiä).
    lea line_buf(%rip), %rsi
    // h
    cmpb $'h', (%rsi)
    // Ei help → palaa kerneliin.
    jne .Ldone
    // e
    cmpb $'e', 1(%rsi)
    jne .Ldone
    // l
    cmpb $'l', 2(%rsi)
    jne .Ldone
    // p
    cmpb $'p', 3(%rsi)
    jne .Ldone
    // sys_write(1, help_text, help_len) — tulosta komentolista.
    mov $1, %rax
    mov $1, %rdi
    lea help_text(%rip), %rsi
    mov $help_len, %rdx
    syscall
.Ldone:
    // SYS_test_return (10) — palaa kernel boot-jatkoon.
    mov $10, %rax
    // Ei argumentteja.
    xor %rdi, %rdi
    // Paluu shell.zig launch-jatkoon.
    syscall
    // Ei saavuteta.
    ud2

// Prompt merkkijono — .text:ssä jotta toinen PT_LOAD ei ylikirjoita koodia.
prompt:
    .ascii "zinux> "
// help-komennon vastaus — .text:ssä samalla sivulla kuin _start.
help_text:
    .ascii "Available commands:\n  help    - show this help\n  meminfo - memory info\n  ps      - list processes\n"
help_len = . - help_text

// Nollattu puskuri rivinlukuun — erillinen BSS-sivu (ALIGN 0x1000 user.ld:ssä).
.section .bss
.align 16
line_buf:
    .space 128
