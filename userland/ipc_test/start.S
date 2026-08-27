// Käyttäjätilan IPC-testi — hyppää Zig ipcMain:iin.
.global _start
.extern ipcMain

_start:
    // Kutsu Zig IPC-testi (send/recv roundtrip).
    call ipcMain
    // Ei saavuteta — ipcMain kutsuu sys_test_return.
    ud2
