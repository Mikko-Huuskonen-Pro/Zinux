// Loader-testi käyttäjäohjelma — sys_write("elf") + SYS_test_return.
.global _start

_start:
    // sys_write(1, msg, 3) — RAX = SYS_write (1).
    mov $1, %rax
    // fd = stdout.
    mov $1, %rdi
    // Merkkijono .rodata:ssa.
    lea msg(%rip), %rsi
    // Kolme tavua "elf".
    mov $3, %rdx
    // Siirry kerneliin.
    syscall
    // SYS_test_return (10) — palaa kernel boot-jatkoon.
    mov $10, %rax
    // Ei argumentteja.
    xor %rdi, %rdi
    // Paluu loader-testiin.
    syscall
    // Ei saavuteta.
    ud2

msg:
    // Odotettu serial-tulos loader-testissä.
    .ascii "elf"
