// Käyttäjätilan ipc queue capacity -testi — hyppää Zig ipcQueueCapacityMain:iin.
.global _start
.extern ipcQueueCapacityMain

_start:
    // Kutsu Zig ipc queue capacity -testi (capacity + pending ≤ max).
    call ipcQueueCapacityMain
    // Ei saavuteta — ipcQueueCapacityMain kutsuu sys_test_return.
    ud2
