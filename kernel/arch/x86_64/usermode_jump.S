// Ring 3 siirtymä ja paluu — iretq + ret.
.global usermodeEnterIret
.global usermodeReturnToKernel
.global usermode_saved_kernel_rsp

usermodeEnterIret:
    // RDI=entry, RSI=user_stack, RDX=user_cs, RCX=user_ss, R8=rflags.
    // Tallenna kernel RSP ennen iretq-kehyksen rakentamista.
    mov %rsp, usermode_saved_kernel_rsp(%rip)
    // iretq pinon kehys (viimeinen push = RIP, popataan ensin).
    push %rcx
    push %rsi
    push %r8
    push %rdx
    push %rdi
    // Siirry ring 3:een.
    iretq

usermodeReturnToKernel:
    // Palauta boot-pino ja hyppää runBootTest-jatkoon.
    mov usermode_saved_kernel_rsp(%rip), %rsp
    ret
