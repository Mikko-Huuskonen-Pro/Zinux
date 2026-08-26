// PS/2-näppäimistö IRQ1 (vektori 33) — EOI + C-käsittelijä.
.global keyboardIrqHandler
keyboardIrqHandler:
    // Tallenna clobber-rekisterit ennen C-kutsua.
    push %rax
    // Toinen caller-saved.
    push %rcx
    // Kolmas caller-saved.
    push %rdx
    // 16-tavun aligned stack ennen call (SysV ABI).
    sub $8, %rsp
    // Kutsu keyboardOnIrqC — lukee scancoden ja puskee UART-rengasjonoon.
    call keyboardOnIrqC
    // Palauta stack alignment.
    add $8, %rsp
    // Palauta rekisterit.
    pop %rdx
    pop %rcx
    pop %rax
    // Master PIC EOI — IRQ1 on masterin linja 1.
    mov $0x20, %al
    // Lähetä EOI master PIC:lle (portti 0x20).
    out %al, $0x20
    // Salli keskeytykset ennen iretq.
    sti
    // Palaa keskeytettyyn koodiin.
    iretq
