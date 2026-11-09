import Foundation
import Testing

@testable import KiwiDeskCore

/// While KiwiHub holds the keyboard a modifier tap fires nothing
/// (#1229): its own keys ride ⌘, ⇧, ⌥ and ⌃, so a quick ⌘ press
/// there must not toggle the panel. A chord row still fires.
@Suite("KiwiHub holds modifier taps (#1229)", .serialized)
@MainActor
struct KiwiHubHeldTapTests {
    private func rig() throws -> (KiwiCore, () -> [FakeKeyboardTap]) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-hubtap-\(UUID().uuidString)")
        )
        var made: [FakeKeyboardTap] = []
        core.keys.makeKeyboardTap = { consumers, fire, _ in
            let tap = FakeKeyboardTap(consumers, fire)
            made.append(tap)
            return tap
        }
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        KiwiDesk.bind("cmd+cmd", function() taps = (taps or 0) + 1 end)
        KiwiDesk.bind("rcmd", function() singles = (singles or 0) + 1 end)
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return (core, { made })
    }

    private func id(
        of text: String,
        in taps: [FakeKeyboardTap]
    ) throws -> UInt32 {
        let combo = try #require(KeyCombo.parse(text))
        let row = taps.last?.tapRows.first { $0.combo == combo }
        return try #require(row).id
    }

    @Test("a held tap fires nothing; released, it fires again")
    func heldTapFiresNothing() throws {
        let (core, taps) = try rig()
        let double = try id(of: "cmd+cmd", in: taps())
        let single = try id(of: "rcmd", in: taps())
        core.setKiwiHubHoldsKeys(true)
        core.keys.tapFire(double)
        core.keys.tapFire(single)
        #expect(core.lua?.global("taps") == LuaValue.none)
        #expect(core.lua?.global("singles") == LuaValue.none)
        core.setKiwiHubHoldsKeys(false)
        core.keys.tapFire(double)
        #expect(core.lua?.global("taps") == .number(1))
    }
}
