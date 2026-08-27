// Käyttäjätilan ipc flush -testi — hyppää Zig ipcFlushMain:iin.
.global _start
.extern ipcFlushMain

_start:
    // Kutsu Zig ipc flush -testi (send/pending/flush/empty).
    call ipcFlushMain
    // Ei saavuteta — ipcFlushMain kutsuu sys_test_return.
    ud2
