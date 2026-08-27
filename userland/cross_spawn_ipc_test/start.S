// Cross-spawn IPC parent — hyppää Zig crossSpawnIpcMain:iin.
.global _start
.extern crossSpawnIpcMain

_start:
    // Kutsu Zig parent: spawn + transfer + send.
    call crossSpawnIpcMain
    // Ei saavuteta — crossSpawnIpcMain kutsuu sys_test_return.
    ud2
