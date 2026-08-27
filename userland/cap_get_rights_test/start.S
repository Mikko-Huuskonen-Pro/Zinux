// Käyttäjätilan cap get rights -testi — hyppää Zig capGetRightsMain:iin.
.global _start
.extern capGetRightsMain

_start:
    // Kutsu Zig cap get rights -testi (getRights parent/derived).
    call capGetRightsMain
    // Ei saavuteta — capGetRightsMain kutsuu sys_test_return.
    ud2
