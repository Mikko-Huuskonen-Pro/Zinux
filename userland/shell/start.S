// Shell-sisäänkäynti — hyppää Zig shellMain:iin (komennot commands/*.zig).
.global _start
.extern shellMain

_start:
    // Kutsu Zig-shell (prompt + read + dispatch).
    call shellMain
    // Ei saavuteta — shellMain kutsuu sys_test_return.
    ud2
