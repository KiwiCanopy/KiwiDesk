import Testing

@testable import KiwiDeskCore

/// A registrar that records every Carbon registration.
@MainActor
private final class RecordingRegistrar: HotkeyRegistrar {
    private(set) var codes: [UInt32: UInt32] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        codes[nextID] = keyCode
        return nextID
    }

    func unregister(id: UInt32) { codes[id] = nil }
}

/// How modifier taps reach the one keyboard tap (#1872): every tap
/// row rides the `.modifierTaps` consumer and none reaches Carbon,
/// the tap is rebuilt when its consumers change, and no tap row
/// means no consumer.
@Suite("Keyboard tap routing (#1872)", .serialized)
@MainActor
struct KeyboardTapRoutingTests {
    private func rig() -> (
        KeybindingManager, RecordingRegistrar, () -> [FakeKeyboardTap]
    ) {
        let registrar = RecordingRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        manager.onLog = { _ in }
        var made: [FakeKeyboardTap] = []
        manager.makeKeyboardTap = { consumers, fire, _ in
            let tap = FakeKeyboardTap(consumers, fire)
            made.append(tap)
            return tap
        }
        return (manager, registrar, { made })
    }

    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("a tap row rides the tap and never reaches Carbon")
    func tapsNeverReachCarbon() throws {
        let (manager, registrar, taps) = rig()
        manager.bind(try combo("cmd+cmd"), ref: 1)
        manager.bind(try combo("rcmd"), ref: 2)
        manager.bind(try combo("cmd+h"), ref: 3)
        #expect(
            registrar.codes.values.sorted() == [try combo("cmd+h").keyCode]
        )
        let tap = try #require(taps().last)
        #expect(tap.consumers == [.modifierTaps])
        #expect(
            Set(tap.tapRows.map(\.combo))
                == [try combo("cmd+cmd"), try combo("rcmd")]
        )
        #expect(manager.activationFailures.isEmpty)
    }

    @Test("no tap row, no consumer; the last row stops the tap")
    func noTapRowNoConsumer() throws {
        let (manager, _, taps) = rig()
        manager.bind(try combo("cmd+h"), ref: 1)
        #expect(taps().isEmpty)
        manager.bind(try combo("cmd+cmd"), ref: 2)
        let tap = try #require(taps().last)
        manager.reset()
        manager.bind(try combo("cmd+h"), ref: 3)
        #expect(tap.stopped)
        #expect(taps().count == 1)
        #expect(manager.sideTapStatus == .off)
    }

    @Test("a changed consumer set rebuilds the tap with the union")
    func consumersRebuild() throws {
        let (manager, _, taps) = rig()
        manager.bind(try combo("cmd+cmd"), ref: 1)
        let first = try #require(taps().last)
        manager.bind(try combo("rcmd+h"), ref: 2)
        manager.modifierSides = true
        let second = try #require(taps().last)
        #expect(first.stopped)
        #expect(second.consumers == [.sides, .modifierTaps])
        #expect(second.rows.count == 1)
        #expect(second.tapRows.count == 1)
        // The same set again keeps the tap.
        manager.bind(try combo("ropt"), ref: 3)
        #expect(taps().last === second)
    }

    @Test("a refused tap lists its tap rows as failures")
    func refusedTapRowsFail() throws {
        let (manager, registrar, _) = rig()
        manager.makeKeyboardTap = { _, _, _ in nil }
        manager.bind(try combo("cmd+cmd"), ref: 1)
        #expect(manager.activationFailures == [try combo("cmd+cmd")])
        #expect(registrar.codes.isEmpty)
        #expect(manager.sideTapStatus == .refused)
    }

    @Test("suspended, the tap answers no tap")
    func suspendedEmptiesTaps() throws {
        let (manager, _, taps) = rig()
        manager.bind(try combo("cmd+cmd"), ref: 1)
        let tap = try #require(taps().last)
        manager.suspend()
        #expect(tap.tapRows.isEmpty)
        manager.resume()
        #expect(!(taps().last?.tapRows.isEmpty ?? true))
    }

    @Test("a sided tap row wins on its side, either-side the other")
    func routerMatch() {
        let either = ModifierTapRow(
            combo: KeyCombo.tap(.command, side: nil, count: 2)!,
            id: 1
        )
        let right = ModifierTapRow(
            combo: KeyCombo.tap(.command, side: .right, count: 2)!,
            id: 2
        )
        let rows = [right, either]
        let onRight = ModifierTap(ModifierKey(.command, .right), count: 2)
        let onLeft = ModifierTap(ModifierKey(.command, .left), count: 2)
        #expect(ModifierTapRouter.match(rows, onRight)?.id == 2)
        #expect(ModifierTapRouter.match(rows, onLeft)?.id == 1)
        let single = ModifierTap(ModifierKey(.command, .right), count: 1)
        #expect(ModifierTapRouter.match(rows, single) == nil)
    }

    @Test("a single tap waits only on a key a double tap listens on")
    func immediateKeys() {
        let rows = [
            ModifierTapRow(
                combo: KeyCombo.tap(.command, side: .right, count: 1)!,
                id: 1
            ),
            ModifierTapRow(
                combo: KeyCombo.tap(.option, side: nil, count: 2)!,
                id: 2
            ),
        ]
        let immediate = ModifierTapRouter.immediateKeys(rows)
        #expect(immediate.contains(ModifierKey(.command, .right)))
        #expect(!immediate.contains(ModifierKey(.option, .right)))
        #expect(!immediate.contains(ModifierKey(.option, .left)))
        var router = ModifierTapRouter()
        router.setRows(rows)
        let held = HotkeyModifiers.command.union(.side(.right, of: .command))
        _ = router.feed(.flags(held, at: 0))
        #expect(router.feed(.flags([], at: 0.1)).ids == [1])
    }

    @Test("a fired tap runs its row's binding")
    func fireReachesTheBinding() throws {
        let (manager, _, taps) = rig()
        manager.bind(try combo("cmd+cmd"), ref: 7)
        let row = try #require(taps().last?.tapRows.first)
        #expect(manager.tapBindings[row.id]?.ref == 7)
        manager.suspend()
        #expect(manager.tapBindings[row.id] == nil)
    }
}
