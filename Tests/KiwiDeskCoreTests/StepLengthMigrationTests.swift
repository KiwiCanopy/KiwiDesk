import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored `step_distance` (pt, #1772) leaves every
/// `scroll_gesture` group for the mm `step_length`'s default (#1873
/// ▸ Ruling 2026-11-16): in `gui.json`, a backup's `config` and
/// `profiles[]`, and a profile file. Fixtures are the encoder's own
/// output with the retired key written back, as an older build left
/// it.
@Suite("Step length migration (#1873)")
struct StepLengthMigrationTests {
    private static let retired = "step_distance"

    private var profile: Profile {
        Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["m"])],
            spaceModes: [:],
            settings: TilingSettings(),
            scrollGesture: ScrollGestureOverride(longSwipes: true)
        )
    }

    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
    }

    /// `group`'s `scroll_gesture` with the retired key put back.
    private func retiring(_ group: [String: Any]) -> [String: Any] {
        var out = group
        var gesture = out["scroll_gesture"] as? [String: Any] ?? [:]
        gesture[Self.retired] = 120
        out["scroll_gesture"] = gesture
        return out
    }

    private func data(_ root: [String: Any]) throws -> Data {
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        #expect(
            String(decoding: data, as: UTF8.self).contains(Self.retired)
        )
        return data
    }

    private func gui(format: Int) throws -> Data {
        var root = retiring(try object(GuiConfig()))
        root["format"] = format
        return try data(root)
    }

    private func carries(_ out: Data) -> Bool {
        String(decoding: out, as: UTF8.self).contains(Self.retired)
    }

    /// From 4.2.1's stamp (19) and from the format below the branch's
    /// bump (26).
    @Test("gui.json drops the key", arguments: [19, 26])
    func guiDrops(from format: Int) throws {
        let out = try #require(ConfigMigration.migrated(gui(format: format)))
        #expect(!carries(out))
        let read = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(
            read.scrollGesture.stepLength
                == ScrollGestureBase.defaults.stepLength
        )
    }

    @Test("a profile file drops the key")
    func profileDrops() throws {
        var root = retiring(try object(profile))
        root["format"] = Profile.currentFormat - 1
        let out = try #require(ConfigMigration.migrated(data(root)))
        #expect(!carries(out))
        _ = try JSONDecoder().decode(Profile.self, from: out)
    }

    /// From 4.2.1's backup stamp (43) and from 50: the config and
    /// every inline profile.
    @Test("a backup drops it everywhere", arguments: [43, 50])
    func bundleDrops(from format: Int) throws {
        var root = try object(
            SetupBundle(
                format: format,
                writtenBy: "test",
                config: GuiConfig(),
                profiles: [profile],
                palettes: []
            )
        )
        root["config"] = retiring(
            try #require(root["config"] as? [String: Any])
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        root["profiles"] = profiles.map(retiring)
        root["format"] = format
        let out = try #require(ConfigMigration.migrated(data(root)))
        #expect(!carries(out))
    }

    /// The edit removes the member and its comma, and every other
    /// byte stays as written.
    @Test("the edit is surgical")
    func editIsSurgical() throws {
        let text = String(decoding: try gui(format: 26), as: UTF8.self)
        let edited = try #require(ConfigMigration.stepDistanceTextOut(text))
        let out = String(decoding: edited, as: UTF8.self)
        #expect(!out.contains(Self.retired))
        let kept = text.replacingOccurrences(
            of: "\\s*\"\(Self.retired)\" : 120,?",
            with: "",
            options: .regularExpression
        )
        #expect(
            out.filter { !$0.isWhitespace } == kept.filter { !$0.isWhitespace }
        )
        _ = try JSONSerialization.jsonObject(with: edited)
        // A spacing the walk would not keep: the migration's answer
        // is the edit's, never a re-serialization.
        let spaced = text.replacingOccurrences(
            of: "\"format\" : ",
            with: "\"format\" :  "
        )
        let migrated = try #require(
            ConfigMigration.migratingStepDistanceOut(Data(spaced.utf8))
        )
        #expect(
            String(decoding: migrated, as: UTF8.self)
                .contains("\"format\" :  ")
        )
    }

    /// A key outside a `scroll_gesture` group is not the setting.
    @Test("only a scroll_gesture group loses it")
    func onlyTheGroup() throws {
        let text = "{\"other\" : {\"step_distance\" : 5}}"
        #expect(ConfigMigration.stepDistanceTextOut(text) == nil)
        let (_, changed) = ConfigMigration.withoutStepDistance(
            try JSONSerialization.jsonObject(with: Data(text.utf8))
        )
        #expect(!changed)
    }

    @Test("a file without the key is left alone")
    func absentIsANoOp() throws {
        var root = try object(GuiConfig())
        root["format"] = 26
        let clean = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingStepDistanceOut(clean) == nil)
    }
}
