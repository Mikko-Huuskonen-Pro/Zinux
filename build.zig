//! Zinux kernel — build-konfiguraatio (Zig 0.16).
//!
//! **Vastuu**: Käännä freestanding kernel, luo ISO, käynnistä QEMU.
//! **Käyttö**:
//!   `zig build`        — käännä kernel.elf
//!   `zig build iso`    — luo bootattava ISO
//!   `zig build run`    — käynnistä QEMU:ssa
//!   `zig build test`   — aja host-yksikkötestit

const std = @import("std");

// Limine-binäärit ladataan tähän cache-hakemistoon ensimmäisellä ISO-buildillä.
const limine_version = "12.6.1";
const limine_cache = ".zig-cache/limine";

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Freestanding x86_64 — ei SSE/AVX (ei FPU-tilan tallennusta bootissa).
    var query = std.Target.Query{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    query.cpu_features_add = std.Target.x86.featureSet(&.{.soft_float});
    query.cpu_features_sub = std.Target.x86.featureSet(&.{
        .mmx, .sse, .sse2, .sse3, .ssse3, .sse4_1, .sse4_2, .avx, .avx2,
    });
    const target = b.resolveTargetQuery(query);

    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("kernel/main.zig"),
        .target = target,
        // ReleaseSafe freestandingissä — Debug vetää UBSAN/SSE-runtimea jota ei ole.
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });
    kernel_mod.red_zone = false;
    kernel_mod.stack_protector = false;
    kernel_mod.code_model = .kernel;
    kernel_mod.single_threaded = true;
    const abi_mod = b.createModule(.{
        .root_source_file = b.path("libs/zinuxabi.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });
    kernel_mod.addImport("zinuxabi", abi_mod);

    // --- Loader-testi user-ELF (Vaihe 5.1) — upotetaan kerneliin ---
    const user_test_mod = b.createModule(.{
        .root_source_file = b.path("userland/loader_test/main.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });
    user_test_mod.red_zone = false;
    user_test_mod.stack_protector = false;
    user_test_mod.single_threaded = true;
    const user_test_exe = b.addExecutable(.{
        .name = "loader-test-user",
        .root_module = user_test_mod,
    });
    user_test_exe.setLinkerScript(b.path("userland/user.ld"));
    user_test_exe.root_module.addAssemblyFile(b.path("userland/loader_test/start.S"));
    b.installArtifact(user_test_exe);

    const embedded_elf_path = b.path("kernel/loader/test_prog.bin");
    const copy_test_elf = b.addSystemCommand(&.{ "cp", "-f" });
    copy_test_elf.addFileArg(user_test_exe.getEmittedBin());
    copy_test_elf.addFileArg(embedded_elf_path);
    copy_test_elf.step.dependOn(&user_test_exe.step);

    // --- Init-prosessi user-ELF (Vaihe 5.2) — upotetaan kerneliin ---
    const init_mod = b.createModule(.{
        .root_source_file = b.path("userland/init/main.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });
    init_mod.red_zone = false;
    init_mod.stack_protector = false;
    init_mod.single_threaded = true;
    const init_exe = b.addExecutable(.{
        .name = "zinux-init",
        .root_module = init_mod,
    });
    init_exe.setLinkerScript(b.path("userland/init/user.ld"));
    init_exe.root_module.addAssemblyFile(b.path("userland/init/start.S"));
    b.installArtifact(init_exe);

    const embedded_init_path = b.path("kernel/loader/init_prog.bin");
    const copy_init_elf = b.addSystemCommand(&.{ "cp", "-f" });
    copy_init_elf.addFileArg(init_exe.getEmittedBin());
    copy_init_elf.addFileArg(embedded_init_path);
    copy_init_elf.step.dependOn(&init_exe.step);

    // --- Shell user-ELF (Vaihe 5.3) — upotetaan kerneliin ---
    const shell_mod = b.createModule(.{
        .root_source_file = b.path("userland/shell/main.zig"),
        .target = target,
        .optimize = if (optimize == .Debug) .ReleaseSafe else optimize,
    });
    shell_mod.red_zone = false;
    shell_mod.stack_protector = false;
    shell_mod.single_threaded = true;
    const shell_exe = b.addExecutable(.{
        .name = "zinux-shell",
        .root_module = shell_mod,
    });
    shell_exe.setLinkerScript(b.path("userland/shell/user.ld"));
    shell_exe.root_module.addAssemblyFile(b.path("userland/shell/start.S"));
    b.installArtifact(shell_exe);

    const embedded_shell_path = b.path("kernel/loader/shell_prog.bin");
    const copy_shell_elf = b.addSystemCommand(&.{ "cp", "-f" });
    copy_shell_elf.addFileArg(shell_exe.getEmittedBin());
    copy_shell_elf.addFileArg(embedded_shell_path);
    copy_shell_elf.step.dependOn(&shell_exe.step);

    const kernel = b.addExecutable(.{
        .name = "zinux-kernel",
        .root_module = kernel_mod,
    });
    kernel.setLinkerScript(b.path("linker.ld"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/context_switch.S"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/timer_irq.S"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/syscall_entry.S"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/usermode_entry.S"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/usermode_jump.S"));
    kernel.root_module.addAssemblyFile(b.path("kernel/arch/x86_64/keyboard_irq.S"));
    kernel.step.dependOn(&copy_test_elf.step);
    kernel.step.dependOn(&copy_init_elf.step);
    kernel.step.dependOn(&copy_shell_elf.step);
    b.installArtifact(kernel);

    // --- Host-testit ---
    const pmm_mod = b.createModule(.{
        .root_source_file = b.path("kernel/mm/pmm.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const heap_core_mod = b.createModule(.{
        .root_source_file = b.path("kernel/mm/heap_core.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const capability_core_mod = b.createModule(.{
        .root_source_file = b.path("kernel/ipc/capability_core.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const port_core_mod = b.createModule(.{
        .root_source_file = b.path("kernel/ipc/port_core.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const elf_core_mod = b.createModule(.{
        .root_source_file = b.path("kernel/loader/elf_core.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const host_test_mod = b.createModule(.{
        .root_source_file = b.path("tests/host/root.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    host_test_mod.addImport("pmm", pmm_mod);
    host_test_mod.addImport("heap_core", heap_core_mod);
    host_test_mod.addImport("capability_core", capability_core_mod);
    host_test_mod.addImport("port_core", port_core_mod);
    const host_tests = b.addTest(.{
        .root_module = host_test_mod,
    });
    const elf_core_tests = b.addTest(.{
        .root_module = elf_core_mod,
    });
    elf_core_tests.step.dependOn(&copy_test_elf.step);
    const run_host_tests = b.step("test", "Run host unit tests");
    run_host_tests.dependOn(&b.addRunArtifact(host_tests).step);
    run_host_tests.dependOn(&b.addRunArtifact(elf_core_tests).step);

    // --- Limine binary fetch + host tool build ---
    const cache_path = b.pathFromRoot(limine_cache);
    const fetch_limine = b.addSystemCommand(&.{
        "bash", "-c",
        b.fmt(
            \\set -euo pipefail
            \\CACHE="{s}"
            \\if [ ! -f "$CACHE/limine-bios-cd.bin" ]; then
            \\  mkdir -p "$CACHE"
            \\  curl -fsSL "https://github.com/Limine-Bootloader/Limine/releases/download/v{s}/limine-binary.tar.xz" \
            \\    | tar xJ --strip-components=1 -C "$CACHE"
            \\fi
            \\if [ ! -x "$CACHE/limine" ]; then
            \\  cc -g -O2 -std=c99 -D_FILE_OFFSET_BITS=64 "$CACHE/limine.c" -o "$CACHE/limine"
            \\fi
        , .{ cache_path, limine_version }),
    });

    // --- ISO root layout ---
    const iso_root_rel = "zig-out/iso-root";
    const iso_path_rel = "zig-out/zinux.iso";
    const root_path = b.pathFromRoot(iso_root_rel);
    const iso_path = b.pathFromRoot(iso_path_rel);
    const kernel_path = b.pathFromRoot("zig-out/bin/zinux-kernel");
    const limine_conf_path = b.pathFromRoot("limine.conf");

    const mk_iso_root = b.addSystemCommand(&.{
        "bash", "-c",
        b.fmt(
            \\set -euo pipefail
            \\ROOT="{s}"
            \\rm -rf "$ROOT"
            \\mkdir -p "$ROOT/boot/limine" "$ROOT/EFI/BOOT"
            \\cp "{s}" "$ROOT/boot/zinux-kernel"
            \\cp "{s}" "$ROOT/boot/limine/limine.conf"
            \\CACHE="{s}"
            \\cp "$CACHE/limine-bios-cd.bin" "$CACHE/limine-bios.sys" "$CACHE/limine-uefi-cd.bin" "$ROOT/boot/limine/"
            \\cp "$CACHE/BOOTX64.EFI" "$CACHE/BOOTIA32.EFI" "$ROOT/EFI/BOOT/"
        , .{ root_path, kernel_path, limine_conf_path, cache_path }),
    });
    mk_iso_root.step.dependOn(b.getInstallStep());
    mk_iso_root.step.dependOn(&fetch_limine.step);

    const xorriso = b.addSystemCommand(&.{
        "xorriso", "-as", "mkisofs",
        "-R", "-r", "-J",
        "-b", "boot/limine/limine-bios-cd.bin",
        "-no-emul-boot", "-boot-load-size", "4", "-boot-info-table",
        "-hfsplus", "-apm-block-size", "2048",
        "--efi-boot", "boot/limine/limine-uefi-cd.bin",
        "-efi-boot-part", "--efi-boot-image", "--protective-msdos-label",
        "-o",
    });
    xorriso.addFileArg(b.path(iso_path_rel));
    xorriso.addDirectoryArg(b.path(iso_root_rel));
    xorriso.step.dependOn(&mk_iso_root.step);

    const limine_install = b.addSystemCommand(&.{
        "bash", "-c",
        b.fmt(
            \\"{s}/limine" bios-install "{s}"
        , .{ cache_path, iso_path }),
    });
    limine_install.step.dependOn(&xorriso.step);
    limine_install.step.dependOn(&fetch_limine.step);

    const iso_step = b.step("iso", "Build bootable Zinux ISO");
    iso_step.dependOn(&limine_install.step);

    // --- QEMU run (headless — toimii CI:ssä ilman GTK-näyttöä) ---
    const qemu = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-M", "q35",
        "-m", "512M",
        "-display", "none",
        "-monitor", "none",
        "-serial", "stdio",
        "-no-reboot",
        "-no-shutdown",
        "-cdrom",
    });
    qemu.addFileArg(b.path(iso_path_rel));
    qemu.step.dependOn(&limine_install.step);

    const run_step = b.step("run", "Run Zinux in QEMU");
    run_step.dependOn(&qemu.step);
}
