// Spawn cap -testi — hyppää Zig spawnCapMain:iin.
.global _start
.extern spawnCapMain

_start:
    // Kutsu Zig spawn + cap.transfer -demo.
    call spawnCapMain
    // Ei saavuteta — spawnCapMain kutsuu sys_test_return.
    ud2
