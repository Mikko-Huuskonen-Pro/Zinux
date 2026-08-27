// Käyttäjätilan IPC block -testi — hyppää Zig ipcBlockMain:iin.
.global _start
.extern ipcBlockMain

_start:
    // Kutsu Zig blocking recv -testi.
    call ipcBlockMain
    // Ei saavuteta — ipcBlockMain kutsuu sys_test_return.
    ud2
