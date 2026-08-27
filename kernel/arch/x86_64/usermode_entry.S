// Ring 3 testikoodi — sys_write("hello") + SYS_test_return takaisin kerneliin.
.global userEntry
.global userEntryEnd

userEntry:
    // sys_write(1, userHello, 5) — RAX=SYS_write.
    mov $1, %rax
    // fd = stdout.
    mov $1, %rdi
    // Puskurin osoite (samalla sivulla kopioidun koodin kanssa).
    lea userHello(%rip), %rsi
    // Viiden merkin "hello".
    mov $5, %rdx
    // Siirry kerneliin SYSCALL:lla.
    syscall
    // SYS_test_return (10) — palaa kernel boot-jatkoon.
    mov $10, %rax
    // Ei argumentteja.
    xor %rdi, %rdi
    // Paluu kerneliin.
    syscall
    // Ei saavuteta.
    ud2

userHello:
    // Testiviesti serialiin (sys_write).
    .ascii "hello"

userEntryEnd:
