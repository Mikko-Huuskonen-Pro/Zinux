// Käyttäjätilan cap-testi — hyppää Zig capMain:iin.
.global _start
.extern capMain

_start:
    // Kutsu Zig cap-delegointitesti.
    call capMain
    // Ei saavuteta — capMain kutsuu sys_test_return.
    ud2
