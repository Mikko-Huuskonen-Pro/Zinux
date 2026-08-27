// Käyttäjätilan ipc try recv -testi — hyppää Zig ipcTryRecvMain:iin.
.global _start
.extern ipcTryRecvMain

_start:
    // Kutsu Zig ipc try recv -testi (tryRecv empty/send/recv/empty).
    call ipcTryRecvMain
    // Ei saavuteta — ipcTryRecvMain kutsuu sys_test_return.
    ud2
