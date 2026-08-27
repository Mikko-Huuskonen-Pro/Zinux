// Spawn-lapsi A — sys_write("spa\n") + SYS_test_return.
.global _start

_start:
    // sys_write(1, msg, 4) — RAX = SYS_write (1).
    mov $1, %rax
    // fd = stdout (UART).
    mov $1, %rdi
    // Merkkijono .rodata:ssa.
    lea msg(%rip), %rsi
    // Neljä tavua "spa\n".
    mov $4, %rdx
    // Siirry kerneliin SYSCALL:lla.
    syscall
    // SYS_test_return (10) — palaa kerneliin (spawn runProcess jatkuu).
    mov $10, %rax
    // Ei argumentteja.
    xor %rdi, %rdi
    // Paluu spawn boot-testiin.
    syscall
    // Ei saavuteta.
    ud2

msg:
    // Odotettu serial-tulos ennen seuraavaa prosessia.
    .ascii "spa\n"
