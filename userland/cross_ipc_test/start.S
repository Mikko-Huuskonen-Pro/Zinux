// Käyttäjätilan cross-IPC-testi — hyppää Zig crossIpcMain:iin.
.global _start
.extern crossIpcMain

_start:
    // Kutsu Zig cross-IPC-testi (sender tai receiver roolin mukaan).
    call crossIpcMain
    // Ei saavuteta — crossIpcMain kutsuu sys_test_return.
    ud2
