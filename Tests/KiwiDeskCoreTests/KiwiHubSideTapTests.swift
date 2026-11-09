import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// While KiwiHub is key, a modifier tap bound to one of its own
/// sides fires, so it runs that side's toggle as the side's chord
/// does (#1229, amended 2026-11-09). Every other tap, every tap
/// leader, and anything under a bar's grown peek stays held. The
/// exception is the bound action's, never a modifier's.
@Suite("KiwiHub lets its own side taps through (#1229)", .serialized)
struct KiwiHubSideTapTests {
    private final class Fired: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: [UInt32] = []
        var ids: [UInt32] { lock.withLock { stored } }
        func append(_ id: UInt32) { lock.withLock { stored.append(id) } }
    }

    private func flags(_ raw: UInt64) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: raw)
        return event
    }

    /// One press and release of a modifier, by its mask and device
    /// bit.
    private func press(
        _ tap: KeyboardTap,
        _ mask: CGEventFlags,
        device: UInt64
    ) throws {
        _ = tap.handledForTesting(
            .flagsChanged,
            try flags(mask.rawValue | device)
        )
        _ = tap.handledForTesting(.flagsChanged, try flags(0))
    }

    /// ⌘⌘ bound to a side (id 1) and ⌥⌥ to another action (id 2).
    private func rig() throws -> (KeyboardTap, Fired) {
        let fired = Fired()
        let tap = KeyboardTap.unstarted(
            consumers: [.modifierTaps],
            fire: { fired.append($0) }
        )
        tap.setRows(
            KeyboardTapRows(taps: [
                ModifierTapRow(
                    combo: try #require(KeyCombo.parse("cmd+cmd")),
                    id: 1,
                    opensKiwiHubSide: true
                ),
                ModifierTapRow(
                    combo: try #require(KeyCombo.parse("alt+alt")),
                    id: 2
                ),
            ])
        )
        return (tap, fired)
    }

    private func doubleCmd(_ tap: KeyboardTap) throws {
        try press(tap, .maskCommand, device: 0x08)
        try press(tap, .maskCommand, device: 0x08)
    }

    private func doubleAlt(_ tap: KeyboardTap) throws {
        try press(tap, .maskAlternate, device: 0x20)
        try press(tap, .maskAlternate, device: 0x20)
    }

    @Test("under KiwiHub a side's tap fires and another tap is held")
    func sideTapPasses() throws {
        let (tap, fired) = try rig()
        tap.holdTaps(.kiwiHub)
        try doubleCmd(tap)
        try doubleAlt(tap)
        #expect(fired.ids == [1])
    }

    @Test("under a grown peek a side's tap is held too")
    func peekHoldsEverything() throws {
        let (tap, fired) = try rig()
        tap.holdTaps(.all)
        try doubleCmd(tap)
        try doubleAlt(tap)
        #expect(fired.ids.isEmpty)
    }

    @Test("under KiwiHub a tap leader opens no sequence")
    func leaderStaysHeld() throws {
        let fired = Fired()
        let tap = KeyboardTap.unstarted(
            consumers: [.modifierTaps, .sequences],
            fire: { fired.append($0) }
        )
        let leader = try #require(KeyCombo.parse("rcmd"))
        tap.setRows(
            KeyboardTapRows(
                taps: [
                    ModifierTapRow(combo: leader, id: KeyboardTap.leaderID(0))
                ],
                sequences: [
                    KeySequence(
                        leader: leader,
                        stored: "rcmd",
                        steps: [
                            KeySequence.Key(
                                combo: try #require(KeyCombo.parse("t")),
                                stored: "t",
                                action: .run(ref: 7)
                            )
                        ]
                    )
                ]
            )
        )
        tap.holdTaps(.kiwiHub)
        try press(tap, .maskCommand, device: 0x10)
        #expect(fired.ids.isEmpty)
        #expect(tap.drainSequenceDecisions().isEmpty)
    }

    @Test("the hold reads KiwiHub off the own key window")
    func holdIsDerived() {
        #expect(ModifierTapHold(nil) == .none)
        #expect(
            ModifierTapHold(OwnKeyWindowReading(number: 1, isDialog: false))
                == .none
        )
        #expect(
            ModifierTapHold(
                OwnKeyWindowReading(
                    number: 1,
                    isDialog: false,
                    floatsOverWindows: true
                )
            ) == .all
        )
        #expect(
            ModifierTapHold(
                OwnKeyWindowReading(
                    number: 1,
                    isDialog: false,
                    floatsOverWindows: true,
                    isKiwiHub: true
                )
            ) == .kiwiHub
        )
    }

    /// A structured row running a side's own Lua marks its tap,
    /// whatever its modifier; a row on another action does not.
    @Test("the bound action marks the row, never its modifier")
    @MainActor
    func boundActionMarksTheRow() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-hubside-\(UUID().uuidString)")
        )
        let fake = FakeKeyboardTap([.modifierTaps])
        core.keys.makeKeyboardTap = { _, _, _ in fake }
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        core.keys.lua = lua
        core.applyStructuredKeybindings(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [
                        KeyBinding(
                            combo: "cmd+cmd",
                            lua: KiwiHubSide.desktops.lua
                        ),
                        KeyBinding(
                            combo: "ctrl+ctrl",
                            lua: KiwiHubSide.windows.lua
                        ),
                        KeyBinding(
                            combo: "alt+alt",
                            lua: "KiwiDesk.focus(\"left\")"
                        ),
                    ]
                )
            ],
            profile: nil,
            lua: lua
        )
        let marked = Dictionary(
            uniqueKeysWithValues: fake.tapRows.map {
                ($0.combo.comboString() ?? "", $0.opensKiwiHubSide)
            }
        )
        #expect(
            marked == [
                "cmd+cmd": true, "ctrl+ctrl": true, "opt+opt": false,
            ]
        )
        var opened: [KiwiHubSide] = []
        core.uiBridge.onKiwihubShow = { opened.append($0) }
        let side = try #require(
            fake.tapRows.first { $0.combo.comboString() == "cmd+cmd" }
        )
        core.keys.tapFire(side.id)
        #expect(opened == [.desktops])
    }
}
