// Preempt B — sys_write('B') + SYS_test_return @ 0x90090000.
.global _start

_start:
    mov $1, %rax
    mov $1, %rdi
    lea char(%rip), %rsi
    mov $1, %rdx
    syscall
    mov $10, %rax
    xor %rdi, %rdi
    syscall
    ud2

char:
    .ascii "B"
