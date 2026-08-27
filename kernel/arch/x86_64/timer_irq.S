// PIT IRQ0 (vektori 32) — EOI + timer/preempt C-kutsu (Vaihe 26).
.global timerIrqHandler
timerIrqHandler:
    // Tallenna clobber-rekisterit — kehys välitetään C:lle.
    push %rax
    push %rcx
    push %rdx
    push %rsi
    push %rdi
    push %r8
    push %r9
    push %r10
    push %r11
    push %rbp
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    // RDI = osoitin tallennettuun kehykseen (SysV ABI).
    mov %rsp, %rdi
    // Kutsu C: timerOnIrqC + prosessien preempt.
    call timerIrqHandlerC
    // Palauta rekisterit ennen iretq:ä.
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    pop %r11
    pop %r10
    pop %r9
    pop %r8
    pop %rdi
    pop %rsi
    pop %rdx
    pop %rcx
    pop %rax
    // PIC master EOI — IRQ0.
    mov $0x20, %al
    out %al, $0x20
    // Salli keskeytykset ennen paluuta.
    sti
    // Palaa keskeytettyyn koodiin (tai preemptattuun prosessiin).
    iretq
