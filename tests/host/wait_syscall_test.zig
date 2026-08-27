//! Host-testit wait_syscall_core-ytimelle.

const std = @import("std");
const wait = @import("wait_syscall_core");
const proc = @import("process_core");

// Testitila — viimeisin allocoitu lapsi.
var test_child: u64 = 0;
var test_parent: u64 = 1;

// Callback — onko prosessi olemassa.
fn existsCb(pid: u64) bool {
    // Delegoi process_core.exists.
    return proc.exists(pid);
}

// Callback — vanhemman pid.
fn parentOfCb(pid: u64) ?u64 {
    // Delegoi process_core.parentPid.
    return proc.parentPid(pid);
}

// Callback — onko zombie.
fn isZombieCb(pid: u64) bool {
    // Delegoi process_core.isZombie.
    return proc.isZombie(pid);
}

// Callback — exit-koodi.
fn exitCodeCb(pid: u64) ?u32 {
    // Delegoi process_core.exitCode.
    return proc.exitCode(pid);
}

test "tryWaitChild returns exit code for zombie child" {
    // Puhdas tila.
    proc.initCore();
    test_parent = proc.BOOT_PID;
    // Allokoi lapsi.
    test_child = proc.allocNextPid() orelse return error.TestFailed;
    try std.testing.expect(proc.setParentPid(test_child, test_parent));
    // Lapsi elää — wait palauttaa EAGAIN.
    const pending = wait.tryWaitChild(test_parent, test_child, existsCb, parentOfCb, isZombieCb, exitCodeCb);
    try std.testing.expectEqual(wait.EAGAIN, pending);
    // Merkitse zombie exit-koodilla 42.
    try std.testing.expect(proc.markZombie(test_child, 42));
    // Wait palauttaa exit-koodin.
    const got = wait.tryWaitChild(test_parent, test_child, existsCb, parentOfCb, isZombieCb, exitCodeCb);
    try std.testing.expectEqual(@as(i64, 42), got);
}

test "tryWaitChild rejects wrong parent" {
    // Puhdas tila.
    proc.initCore();
    const child = proc.allocNextPid() orelse return error.TestFailed;
    try std.testing.expect(proc.setParentPid(child, 2));
    try std.testing.expect(proc.markZombie(child, 1));
    // Boot (pid 1) ei ole vanhempi.
    const ret = wait.tryWaitChild(proc.BOOT_PID, child, existsCb, parentOfCb, isZombieCb, exitCodeCb);
    try std.testing.expectEqual(wait.ECHILD, ret);
}

test "tryWaitChild esrch for missing pid" {
    // Puhdas tila.
    proc.initCore();
    const ret = wait.tryWaitChild(proc.BOOT_PID, 9999, existsCb, parentOfCb, isZombieCb, exitCodeCb);
    try std.testing.expectEqual(wait.ESRCH, ret);
}

test "markZombie and process state" {
    // Puhdas tila.
    proc.initCore();
    const pid = proc.allocNextPid() orelse return error.TestFailed;
    try std.testing.expectEqual(proc.ProcessState.running, proc.getState(pid).?);
    try std.testing.expect(proc.markZombie(pid, 5));
    try std.testing.expect(proc.isZombie(pid));
    try std.testing.expectEqual(@as(u32, 5), proc.exitCode(pid).?);
    // Tuplazombie hylätään.
    try std.testing.expect(!proc.markZombie(pid, 6));
}
