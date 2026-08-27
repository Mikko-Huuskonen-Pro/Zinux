// Käyttäjätilan ajuritesti — hyppää Zig driverMain:iin.
.global _start
.extern driverMain

_start:
    // Kutsu Zig-ajuritesti (registry init + shutdown).
    call driverMain
    // Ei saavuteta — driverMain kutsuu sys_test_return.
    ud2
