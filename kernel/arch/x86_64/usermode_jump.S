// Ring 3 siirtymä ja paluu — iretq + ret.
.global usermodeEnterIret
.global usermodeEnterIretNoSave
.global usermodeReturnToKernel
.global usermodeSaveKernelRsp
.global usermode_saved_kernel_rsp

usermodeEnterIret:
    // Tallenna kernel RSP ennen iretq-kehyksen rakentamista.
    mov %rsp, usermode_saved_kernel_rsp(%rip)
    // Jatka yhteiseen iretq-polkuun.
    jmp usermodeEnterIretBody

usermodeEnterIretNoSave:
    // Scheduler-polku — boot RSP tallennetaan Zig-puolella ennen ensimmäistä kutsua.
    jmp usermodeEnterIretBody

usermodeEnterIretBody:
    // RDI=entry, RSI=user_stack, RDX=user_cs, RCX=user_ss, R8=rflags.
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

usermodeSaveKernelRsp:
    // Tallenna nykyinen kernel RSP — scheduler säilyttää boot-palon (Vaihe 26).
    mov %rsp, usermode_saved_kernel_rsp(%rip)
    ret
