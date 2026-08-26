// PIT IRQ0 (vektori 32) — EOI + C-kutsu pinon tasaus huomioiden.
.global timerIrqHandler
timerIrqHandler:
    push %rax
    push %rcx
    push %rdx
    sub $8, %rsp
    call timerOnIrqC
    add $8, %rsp
    pop %rdx
    pop %rcx
    pop %rax
    mov $0x20, %al
    out %al, $0x20
    sti
    iretq
