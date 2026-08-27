// Address space A — sys_write("asa\n") + SYS_test_return @ 0x90090000.
.global _start

_start:
    // sys_write(1, msg, 4).
    mov $1, %rax
    mov $1, %rdi
    lea msg(%rip), %rsi
    mov $4, %rdx
    syscall
    // SYS_test_return (10).
    mov $10, %rax
    xor %rdi, %rdi
    syscall
    ud2

msg:
    .ascii "asa\n"
