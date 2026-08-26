//! Zinux kernel — build-konfiguraatio.
//!
//! **Vastuu**: Käännä freestanding kernel, luo ISO, käynnistä QEMU.
//! **Käyttö**:
//!   `zig build`        — käännä kernel.elf
//!   `zig build iso`    — luo bootattava ISO
//!   `zig build run`    — käynnistä QEMU:ssa
//!   `zig build test`   — aja host-yksikkotestit

const std = @import("std");

// build.zig:n entry point — Zig build-järjestelmä kutsuu tätä automaattisesti.
pub fn build(b: *std.Build) void {
    // Lue optimointitaso komentoriviparametrista (-Doptimize=ReleaseSafe jne.).
    const optimize = b.standardOptimizeOption(.{});
    // Määritä freestanding x86_64 -kohde: ei käyttöjärjestelmää, ei libc:tä.
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    // --- Kernel executable ---
    // Luo kernelin suoritettava tiedosto freestanding-ympäristöön.
    const kernel = b.addExecutable(.{
        .name = "zinux-kernel",
        .root_source_file = b.path("kernel/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Aseta linkkeriskripti joka sijoittaa kernelin higher-half-osoitteeseen.
    kernel.setLinkerScript(b.path("linker.ld"));
    // Poista red zone — keskeytykset korruptoivat sen alle jäävän pinon.
    kernel.root_module.red_zone = false;
    // Poista stack protector — ei runtime-tukea freestanding-ympäristössä.
    kernel.root_module.stack_protector = false;
    // Kernel code model — sallii 64-bit relokaatiot higher-half-osoitteeseen.
    kernel.root_module.code_model = .kernel;
    // Yksisäikeinen freestanding — ei tarvitse thread-local storagea.
    kernel.root_module.single_threaded = true;
    // Asenna kernel.elf build-hakemistoon oletusstepin artefaktina.
    b.installArtifact(kernel);

    // --- Host-testit ---
    // Yksikkotestit ajetaan normaalilla host-targetilla (std käytössä).
    const host_tests = b.addTest(.{
        .root_source_file = b.path("tests/host/root.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    // Test-step ajaa kaikki `test`-blokit host-ympäristössä.
    const run_host_tests = b.step("test", "Run host unit tests");
    run_host_tests.dependOn(&b.addRunArtifact(host_tests).step);

    // --- QEMU run (placeholder — vaatii ISO:n Vaihe 1:ssä) ---
    // Tuleva: `zig build run` käynnistää QEMU:n Limine-ISO:lla.
    const run_step = b.step("run", "Run Zinux in QEMU (requires ISO)");
    _ = run_step; // Placeholder kunnes Vaihe 1 valmis.
}
