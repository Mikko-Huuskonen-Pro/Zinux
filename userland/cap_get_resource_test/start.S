// Käyttäjätilan cap get resource -testi — hyppää Zig capGetResourceMain:iin.
.global _start
.extern capGetResourceMain

_start:
    // Kutsu Zig cap get resource -testi (getResource + delegate read check).
    call capGetResourceMain
    // Ei saavuteta — capGetResourceMain kutsuu sys_test_return.
    ud2
