// Cross-spawn IPC child — hyppää Zig crossSpawnChildMain:iin.
.global _start
.extern crossSpawnChildMain

_start:
    // Kutsu Zig child: recv siirretyllä slotilla.
    call crossSpawnChildMain
    // Ei saavuteta — crossSpawnChildMain kutsuu sys_test_return.
    ud2
