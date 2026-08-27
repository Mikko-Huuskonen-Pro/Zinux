//! Spawn-lapsi exit — tyhjä Zig-juuri (koodi start.S:ssä).
//!
//! **Vastuu**: Ring 3 -prosessi joka kutsuu sys_exit(42).
//! **Riippuvuudet**: ei
//! **Käytetään**: build.zig → spawn_child_exit ELF
