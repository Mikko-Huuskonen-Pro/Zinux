// Spawn-lapsi exit — sys_exit(42) (Vaihe 24 boot-testi).
.global _start

_start:
    // sys_exit(status) — RAX = SYS_exit (2).
    mov $2, %rax
    // Exit-koodi 42 odotettu wait-testissä.
    mov $42, %rdi
    // Siirry kerneliin SYSCALL:lla — palaa returnToKernelTestContinue.
    syscall
    // Ei saavuteta.
    ud2
