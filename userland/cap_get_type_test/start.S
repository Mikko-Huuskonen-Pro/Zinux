// Käyttäjätilan cap get type -testi — hyppää Zig capGetTypeMain:iin.
.global _start
.extern capGetTypeMain

_start:
    // Kutsu Zig cap get type -testi (getType + revoke).
    call capGetTypeMain
    // Ei saavuteta — capGetTypeMain kutsuu sys_test_return.
    ud2
