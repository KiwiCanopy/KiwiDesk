import Foundation
import Testing

@testable import KiwiDeskCore

/// Retiring `resize.feedback` (#1255).
///
/// The failure this prevents is SILENT in both directions. An
/// unmigrated file keeps a key nothing reads, so its explicit
/// `true` — written unconditionally by every save under the old
/// default — would sit there looking like a user's choice; and a
/// migration that never RUNS is indistinguishable from one that
/// did, since the new decoder simply defaults and moves on.
@Suite("Refusal sound migration (#1255)")
struct RefusalSoundMigrationTests {
    private func json(_ text: String) -> Data {
        Data(text.utf8)
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    @Test("the retired key is dropped, and nothing else moves")
    func dropsTheRetiredKey() throws {
        let data = json(
            """
            {"format":1,"settings":{"resize":\
            {"feedback":true,"step":75}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let settings = try #require(
            root(out)["settings"] as? [String: Any]
        )
        let resize = try #require(
            settings["resize"] as? [String: Any]
        )
        #expect(resize["feedback"] == nil)
        // The sibling survives: this drops one key, never the
        // group it sat in.
        #expect(resize["step"] as? Double == 75)
    }

    /// The value is NOT carried across, and that is the ruling
    /// rather than an oversight: the old default was written
    /// unconditionally, so an explicit `true` records what a save
    /// did rather than what a user chose, and the cue widened
    /// from one near-unreachable case to every refusal.
    @Test("a stored true does not survive as the new default")
    func doesNotCarryTheOldValue() throws {
        let data = json(
            """
            {"format":1,"settings":{"resize":{"feedback":true}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let settings = try #require(
            root(out)["settings"] as? [String: Any]
        )
        // Neither spelling survives — the new key is absent, and
        // absence is what decodes as OFF.
        #expect(
            (settings["refusal"] as? [String: Any]) == nil
        )
        let bytes = try JSONSerialization.data(
            withJSONObject: settings
        )
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: bytes
        )
        #expect(!decoded.refusalSound)
    }

    /// A `feedback` key under any other parent is left alone —
    /// the walk is scoped to `resize`, so a future config gaining
    /// one elsewhere is not silently eaten.
    @Test("only the resize group's key is touched")
    func scopedToTheResizeGroup() throws {
        let data = json(
            """
            {"format":1,"other":{"feedback":true},\
            "settings":{"resize":{"feedback":true}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let other = try #require(
            root(out)["other"] as? [String: Any]
        )
        #expect(other["feedback"] as? Bool == true)
    }

    /// The trap `ConfigMigration`'s own docstring names: a step
    /// is dead on arrival unless the format stamp reaches it.
    /// `TilingSettings` encodes into all three shapes, so all
    /// three had to move — and a file stamped at the OLD current
    /// format must still be migrated, which is what a missing
    /// bump would break.
    @Test("the step reaches every shape that carries settings")
    func everyShapeIsStamped() {
        #expect(GuiConfig.currentFormat >= 3)
        #expect(Profile.currentFormat >= 3)
        #expect(SetupBundle.currentFormat >= 5)
        let stale = json(
            """
            {"format":2,"settings":{"resize":{"feedback":true}}}
            """
        )
        #expect(ConfigMigration.needsMigration(stale))
        #expect(ConfigMigration.migrated(stale) != nil)
    }

    @Test("a file without the key is not rewritten")
    func untouchedFileStaysUntouched() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),\
            "settings":{"resize":{"step":50}}}
            """
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }
}
