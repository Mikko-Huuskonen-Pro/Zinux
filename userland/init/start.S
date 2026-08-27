// Init-prosessi — ensimmäinen käyttäjätilan prosessi (sys_write + paluu bootiin).
.global _start

_start:
    // sys_write(1, msg, len) — RAX = SYS_write (1).
    mov $1, %rax
    // fd = stdout (UART).
    mov $1, %rdi
    // Merkkijono .rodata:ssa.
    lea msg(%rip), %rsi
    // Viisi tavua "init\n".
    mov $5, %rdx
    // Siirry kerneliin SYSCALL:lla.
    syscall
    // SYS_test_return (10) — palaa kerneliin (boot-testi jatkuu).
    mov $10, %rax
    // Ei argumentteja.
    xor %rdi, %rdi
    // Paluu kernel init launch -jatkoon.
    syscall
    // Ei saavuteta.
    ud2

msg:
    // Odotettu serial-tulos ennen "Init process OK".
    .ascii "init\n"
