// Käyttäjätilan cap revoke -testi — hyppää Zig capRevokeMain:iin.
.global _start
.extern capRevokeMain

_start:
    // Kutsu Zig cap revoke -testi (createPort + revoke + send fail).
    call capRevokeMain
    // Ei saavuteta — capRevokeMain kutsuu sys_test_return.
    ud2
