import Foundation
import Testing

@testable import KiwiDesk

/// The revert register (#792) against the census: every key that
/// names a model path has a writer, and each writer copies the path
/// its key names — the census id is a Swift path, so a writer
/// wired to a neighbour's field reds here rather than reverting
/// the wrong control.
@MainActor
@Suite("Settings revert register (#792)")
struct SettingsRevertRegisterTests {
    /// Model-path keys with no writer, each with the reason.
    private let noWriter: [SettingKey: String] = [
        // A layer's reach is drafted beside the config, in the
        // layer edits, and reverts through the layers (#2022).
        .shortcuts(.layersReach): "layer edits, not a config leaf",
        // A Space id stores only its name, so a rename books as the
        // Space list's add and remove, whose writer reverts it.
        .spaces(.spacesName): "a rename books as the list's rows",
    ]

    /// A census id as the register spells paths: no suffix, every
    /// instance slot `[]`.
    private func spelled(_ id: String) -> String {
        var id = id
        if let space = id.range(of: " (") {
            id = String(id[..<space.lowerBound])
        }
        for slot in ["[space]", "[app]", "[n]", "[screen]"] {
            id = id.replacingOccurrences(of: slot, with: "[]")
        }
        return id
    }

    @Test("every model-path key has a writer, or a stated reason")
    func everyKeyHasAWriter() {
        let keys = SettingKey.allCases.filter {
            SettingsDraftDiff.namesModelPath($0.id)
        }
        #expect(keys.count > 150)
        for key in keys where noWriter[key] == nil {
            #expect(
                SettingsRevertRegister.writers[key] != nil,
                Comment(rawValue: "no writer: \(key.id)")
            )
        }
        for key in SettingsRevertRegister.writers.keys {
            #expect(
                SettingsDraftDiff.namesModelPath(key.id)
                    && noWriter[key] == nil,
                Comment(rawValue: "stray writer: \(key.id)")
            )
        }
    }

    /// Two parts naming one key would leave one writer shadowed.
    @Test("the register's parts name each key once")
    func partsAreDisjoint() {
        let keys = SettingsRevertRegister.parts.flatMap(\.keys)
        #expect(Set(keys).count == keys.count)
    }

    /// A writer copies its key's own path, or the container that
    /// path lives in (a rule list, the Space list, the layers); a
    /// master copies exactly its followers.
    @Test("each writer copies the path its key names")
    func writersCopyTheirPaths() {
        for (key, writer) in SettingsRevertRegister.writers {
            let id = spelled(key.id)
            // A master writes exactly its followers, and beside a
            // follower bar edge the per-screen map the doors clear
            // with it.
            if let followers = SettingKey.masterWrites[key] {
                let maps = followers.filter { $0.hasSuffix(".edge") }
                    .map { $0 + "Override" }
                #expect(Set(writer.paths) == Set(followers + maps))
                continue
            }
            #expect(
                // Never a bare `.` prefix: a parent struct's writer
                // would pass for each of its leaves.
                writer.paths.contains {
                    id == $0 || id.hasPrefix($0 + "[]")
                },
                Comment(rawValue: "\(key.id) ← \(writer.paths)")
            )
        }
    }
}
