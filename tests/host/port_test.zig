//! Host-testit IPC-porttien ytimelle.

const std = @import("std");
const port = @import("port_core");

test "port send recv roundtrip" {
    // Puhdas tila.
    port.initCore();
    // Luo portti.
    const id = port.createPort() orelse return error.TestFailed;
    // Lähetä viesti.
    try std.testing.expectEqual(@as(usize, 3), try port.send(id, "IPC"));
    // Vastaanota.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 3), try port.recv(id, buf[0..3]));
    // Sisältö täsmää.
    try std.testing.expectEqualStrings("IPC", buf[0..3]);
}

test "port queue full and empty" {
    // Puhdas tila.
    port.initCore();
    // Luo portti.
    const id = port.createPort() orelse return error.TestFailed;
    // Täytä jono (MAX_QUEUE viestiä).
    var n: usize = 0;
    while (n < port.MAX_QUEUE) : (n += 1) {
        // Jokainen viesti mahtuu.
        _ = try port.send(id, "x");
    }
    // Seuraava send → full.
    try std.testing.expectError(error.Full, port.send(id, "y"));
    // Tyhjennä jono.
    var buf: [4]u8 = undefined;
    n = 0;
    while (n < port.MAX_QUEUE) : (n += 1) {
        // Jokainen recv onnistuu.
        _ = try port.recv(id, &buf);
    }
    // Tyhjä jono → empty.
    try std.testing.expectError(error.Empty, port.recv(id, &buf));
}

test "port flush queue" {
    // Puhdas tila.
    port.initCore();
    // Luo portti.
    const id = port.createPort() orelse return error.TestFailed;
    // Lähetä kaksi viestiä.
    _ = try port.send(id, "a");
    _ = try port.send(id, "b");
    // Kaksi odottavaa viestiä.
    try std.testing.expectEqual(@as(u8, 2), port.pendingCount(id).?);
    // Tyhjennä jono — poistaa kaksi viestiä.
    try std.testing.expectEqual(@as(u8, 2), try port.flushQueue(id));
    // Tyhjä jono flushin jälkeen.
    try std.testing.expectEqual(@as(u8, 0), port.pendingCount(id).?);
    // Recv epäonnistuu tyhjällä jonolla.
    var buf: [4]u8 = undefined;
    try std.testing.expectError(error.Empty, port.recv(id, &buf));
}

test "port pending count" {
    // Puhdas tila.
    port.initCore();
    // Luo portti.
    const id = port.createPort() orelse return error.TestFailed;
    // Tyhjä jono → 0 odottavaa.
    try std.testing.expectEqual(@as(u8, 0), port.pendingCount(id).?);
    // Lähetä yksi viesti.
    _ = try port.send(id, "x");
    // Yksi odottava viesti.
    try std.testing.expectEqual(@as(u8, 1), port.pendingCount(id).?);
    // Vastaanota viesti.
    var buf: [4]u8 = undefined;
    _ = try port.recv(id, &buf);
    // Tyhjä jono uudelleen.
    try std.testing.expectEqual(@as(u8, 0), port.pendingCount(id).?);
}
