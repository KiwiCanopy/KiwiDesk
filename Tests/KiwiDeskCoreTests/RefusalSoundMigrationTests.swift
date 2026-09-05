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

    /// A PROFILE-shaped root: `TilingSettings` reaches disk in
    /// this shape and in the bundle that carries profiles
    /// inline, never in gui.json, so a fixture stamped like one
    /// would be routed at `GuiConfig.currentFormat` and prove
    /// nothing about the file the key actually sits in.
    private func profile(_ settings: String, format: Int = 1)
        -> Data
    {
        json(
            """
            {"format":\(format),"monitor_sets":{},\
            "settings":\(settings)}
            """
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    @Test("the retired key is dropped, and nothing else moves")
    func dropsTheRetiredKey() throws {
        let data = profile(
            """
            {"resize":{"feedback":true,"step":75}}
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
        let data = profile(#"{"resize":{"feedback":true}}"#)
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
            {"format":1,"monitor_sets":{},\
            "other":{"feedback":true},\
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
    ///
    /// It reaches the shapes that actually CARRY the key, and
    /// no further. `TilingSettings` encodes into profiles and
    /// into bundles; `GuiConfig.CodingKeys` declares no
    /// `settings`, so gui.json never held `resize.feedback` and
    /// bumping it would stamp every gui.json for nothing — which
    /// the previous release then refuses wholesale, taking the
    /// spaces, rules, layers and Desktop bindings beside it
    /// (code review, #1255; the cost is `GuiConfig`'s own
    /// docstring's).
    @Test("the step reaches every shape that carries settings")
    func everyShapeIsStamped() {
        #expect(Profile.currentFormat >= 3)
        #expect(SetupBundle.currentFormat >= 5)
        // …and gui.json is deliberately NOT stamped, which is
        // checkable rather than remembered: the key cannot be
        // there if the container never declares it.
        let gui = try? JSONEncoder().encode(GuiConfig())
        let root =
            gui.flatMap {
                try? JSONSerialization.jsonObject(with: $0)
            } as? [String: Any]
        #expect(root?["settings"] == nil)
        for stale in [
            profile(#"{"resize":{"feedback":true}}"#),
            json(
                """
                {"format":1,"writtenBy":"1.2.0","profiles":[\
                {"settings":{"resize":{"feedback":true}}}]}
                """
            ),
        ] {
            #expect(ConfigMigration.needsMigration(stale))
            #expect(ConfigMigration.migrated(stale) != nil)
        }
    }

    /// The drop is a text edit, so the rest of the user's file
    /// survives byte for byte — a re-serialized document re-encodes
    /// every Double (`ConfigMigration+Surgical`'s docstring carries
    /// the measurement), which is damage this step never came for.
    @Test("a neighbouring Double keeps its own spelling")
    func neighbouringDoublesSurvive() throws {
        let data = profile(
            """
            {"resize":{"feedback":true},"animations":{"gap":0.4}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(text.contains("0.4"))
        #expect(!text.contains("0.40000"))
        #expect(!text.contains("feedback"))
    }

    @Test("a file without the key is not rewritten")
    func untouchedFileStaysUntouched() {
        let data = profile(
            """
            {"resize":{"step":50}}
            """,
            format: Profile.currentFormat
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }
}
