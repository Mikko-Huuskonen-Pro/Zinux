// Käyttäjätilan ipc pending -testi — hyppää Zig ipcPendingMain:iin.
.global _start
.extern ipcPendingMain

_start:
    // Kutsu Zig ipc pending -testi (pending empty/send/recv/empty).
    call ipcPendingMain
    // Ei saavuteta — ipcPendingMain kutsuu sys_test_return.
    ud2
