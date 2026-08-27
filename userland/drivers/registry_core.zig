//! Ajurirekisteri-ydin — probe/init/shutdown-silmukka (host-testattava).
//!
//! **Vastuu**: Käy ajuritaulukko, kutsu probe → init / shutdown.
//! **Riippuvuudet**: `driver.zig`
//! **Käytetään**: `registry.zig`, host-testit

// Tuo Driver-vtable ja virheet.
const driver = @import("driver.zig");

// Uudelleenexportoi tyypit testeille.
pub const Driver = driver.Driver;
// Uudelleenexportoi virheet.
pub const DriverError = driver.DriverError;

// Alusta kaikki taulukon ajurit joilla probe() == true.
pub fn initAll(drivers: []const Driver) DriverError!void {
    // Käy jokainen rekisteröity ajuri.
    for (drivers) |drv| {
        // Ohita jos laite ei ole läsnä.
        if (!drv.probe()) continue;
        // Alusta — virhe keskeyttää ketjun.
        try drv.init();
    }
}

// Sammuta kaikki taulukon ajurit (käänteinen järjestys).
pub fn shutdownAll(drivers: []const Driver) void {
    // Indeksi taaksepäin shutdown-järjestyksessä.
    var i: usize = drivers.len;
    // Käy ajurit lopusta alkuun.
    while (i > 0) {
        // Vähennä ennen käyttöä.
        i -= 1;
        // Ohita jos probe olisi false (ei alustettu).
        if (!drivers[i].probe()) continue;
        // Kutsu shutdown-callback.
        drivers[i].shutdown();
    }
}

// Montako ajuria probe() hyväksyy — apu boot/host-testeihin.
pub fn countProbed(drivers: []const Driver) usize {
    // Laskuri löydetyille laitteille.
    var n: usize = 0;
    // Käy taulukko.
    for (drivers) |drv| {
        // probe true → laske mukaan.
        if (drv.probe()) n += 1;
    }
    // Palauta määrä.
    return n;
}
