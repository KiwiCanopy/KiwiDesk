import Testing

@testable import KiwiDeskCore

/// A registrar that refuses a second registration of one Carbon
/// chord, as `RegisterEventHotKey` does inside one process.
@MainActor
private final class CarbonLikeRegistrar: HotkeyRegistrar {
    private(set) var live: [UInt32: (code: UInt32, mask: UInt32)] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        let mask = modifiers.carbonMask
        guard !live.values.contains(where: { $0 == (keyCode, mask) })
        else { return nil }
        defer { nextID += 1 }
        live[nextID] = (keyCode, mask)
        return nextID
    }

    func unregister(id: UInt32) { live[id] = nil }
}

/// The tap a test reads instead of a session-wide one.
private final class FakeSideTap: SideTapHandle {
    var rows: [SideTapRow] = []
    var stopped = false
    func setRows(_ rows: [SideTapRow]) { self.rows = rows }
    func stop() { stopped = true }
}

/// Which rows the side tap answers (#2601): none while the switch
/// is off, where a sided shortcut is a Carbon hotkey either-side;
/// with it on, every row on a chord a sided row names, and no tap
/// at all while no sided row exists.
@Suite("Modifier side routing (#2601)", .serialized)
@MainActor
struct ModifierSideRoutingTests {
    private struct Rig {
        let manager: KeybindingManager
        let registrar: CarbonLikeRegistrar
        var taps: [FakeSideTap] = []
    }

    private func rig() -> (
        KeybindingManager, CarbonLikeRegistrar, () -> FakeSideTap?
    ) {
        let registrar = CarbonLikeRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        manager.onLog = { _ in }
        var made: [FakeSideTap] = []
        manager.makeSideTap = { _, _ in
            let tap = FakeSideTap()
            made.append(tap)
            return tap
        }
        return (manager, registrar, { made.last })
    }

    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("off: a sided row is a Carbon hotkey either-side, no tap")
    func offIsCarbon() throws {
        let (manager, registrar, tap) = rig()
        manager.bind(try combo("rcmd+h"), ref: 1)
        #expect(registrar.live.count == 1)
        #expect(
            registrar.live.values.first?.mask
                == HotkeyModifiers.command.rawValue
        )
        #expect(tap() == nil)
        #expect(manager.sideTapStatus == .off)
    }

    @Test("off: two rows collapsing onto one chord, the second refused")
    func offCollapses() throws {
        let (manager, _, _) = rig()
        manager.bind(try combo("lcmd+h"), ref: 1)
        manager.bind(try combo("rcmd+h"), ref: 2)
        #expect(manager.activationFailures.count == 1)
        let (other, _, _) = rig()
        other.bind(try combo("cmd+h"), ref: 1)
        other.bind(try combo("rcmd+h"), ref: 2)
        #expect(other.activationFailures.count == 1)
    }

    @Test("on: the sided chord's rows go to the tap, the rest to Carbon")
    func onRoutes() throws {
        let (manager, registrar, tap) = rig()
        manager.bind(try combo("rcmd+h"), ref: 1)
        manager.bind(try combo("cmd+h"), ref: 2)
        manager.bind(try combo("cmd+j"), ref: 3)
        manager.modifierSides = true
        let rows = try #require(tap()).rows
        #expect(
            Set(rows.map(\.modifiers)) == [
                try combo("rcmd+h").modifiers, try combo("cmd+h").modifiers,
            ]
        )
        #expect(registrar.live.count == 1)
        #expect(manager.activationFailures.isEmpty)
        #expect(manager.sideTapStatus == .running)
    }

    @Test("on with no sided row: no tap")
    func onWithoutSidesHasNoTap() throws {
        let (manager, registrar, tap) = rig()
        manager.bind(try combo("cmd+h"), ref: 1)
        manager.modifierSides = true
        #expect(tap() == nil)
        #expect(registrar.live.count == 1)
    }

    @Test("suspending empties the tap; turning it off stops it")
    func offStopsTheTap() throws {
        let (manager, registrar, tap) = rig()
        manager.bind(try combo("rcmd+h"), ref: 1)
        manager.modifierSides = true
        let live = try #require(tap())
        manager.suspend()
        #expect(live.rows.isEmpty)
        manager.resume()
        #expect(tap() === live)
        #expect(!live.rows.isEmpty)
        manager.modifierSides = false
        #expect(live.stopped)
        #expect(registrar.live.count == 1)
        #expect(manager.sideTapStatus == .off)
    }

    @Test("a refused tap reads refused")
    func refusedTap() throws {
        let (manager, _, _) = rig()
        manager.makeSideTap = { _, _ in nil }
        manager.bind(try combo("rcmd+h"), ref: 1)
        manager.modifierSides = true
        #expect(manager.sideTapStatus == .refused)
    }

    @Test("a keypad digit's twin rides the tap too")
    func keypadTwin() throws {
        let (manager, _, tap) = rig()
        manager.bind(try combo("rcmd+1"), ref: 1)
        manager.modifierSides = true
        let codes = Set(try #require(tap()).rows.map(\.keyCode))
        let row = try combo("rcmd+1").keyCode
        let twin = try #require(KeypadKeys.keypadTwin(of: row))
        #expect(codes == [row, twin])
    }
}
