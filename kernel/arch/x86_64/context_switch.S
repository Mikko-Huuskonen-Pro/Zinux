// x86_64 cooperative context switch — callee-saved + RSP swap.
// SysV ABI: RDI = prev_rsp (*u64), RSI = next_rsp (u64).
.global switchContextAsm
switchContextAsm:
    push %rbx
    push %rbp
    push %r12
    push %r13
    push %r14
    push %r15
    mov %rsp, (%rdi)
    mov %rsi, %rsp
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    pop %rbx
    ret
