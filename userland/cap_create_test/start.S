// Käyttäjätilan cap create -testi — hyppää Zig capCreateMain:iin.
.global _start
.extern capCreateMain

_start:
    // Kutsu Zig cap create -testi (createPort + ipc roundtrip).
    call capCreateMain
    // Ei saavuteta — capCreateMain kutsuu sys_test_return.
    ud2
