// x86_64 SYSCALL entry — tallentaa kehyksen, kutsuu syscallDispatchFromFrame, SYSRET.
.global syscallEntry
.global saved_user_rsp
.global syscall_stack_top

syscallEntry:
    // Tallenna käyttäjän RSP ennen kernel pinon vaihtoa.
    mov %rsp, saved_user_rsp(%rip)
    // Lataa kernel syscall pinon yläreuna.
    mov syscall_stack_top(%rip), %rsp
    // Varaa SyscallFrame pinolle (9 * 8 = 72 tavua, + alignment).
    sub $80, %rsp
    // Tallenna syscall-numero ja argumentit kehykseen.
    mov %rax, 0(%rsp)
    mov %rdi, 8(%rsp)
    mov %rsi, 16(%rsp)
    mov %rdx, 24(%rsp)
    mov %r10, 32(%rsp)
    mov %r8, 40(%rsp)
    mov %r9, 48(%rsp)
    mov %rcx, 56(%rsp)
    mov %r11, 64(%rsp)
    // RDI = osoitin kehykseen (SysV C ABI).
    mov %rsp, %rdi
    // Tallenna callee-saved ennen C-kutsua.
    push %rbp
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    // Kutsu C-dispatch.
    call syscallDispatchFromFrame
    // Paluuarvo RAX:ssa.
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    // Poista kehys pinolta.
    add $80, %rsp
    // Lataa käyttäjän RSP.
    mov saved_user_rsp(%rip), %rsp
    // SYSRET vaatii RCX=RIP, R11=RFLAGS — ne ovat yhä alkuperäiset.
    sysretq
