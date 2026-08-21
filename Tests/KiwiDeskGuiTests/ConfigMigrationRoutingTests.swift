import Foundation
import Testing

/// Every reader of a config FILE routes its bytes through
/// `ConfigMigration.migrated` before decoding, and the walk that
/// migration performs may only reach keys it was scoped to.
///
/// Both halves exist because both already failed. The crossing
/// shipped wired to `ProfileManager.read` alone, while
/// `SetupBundle` carries `[Profile]` inline and is the second
/// reader of the same file shape — so a backup written by the
/// build the migration exists to rescue was refused as "not a
/// KiwiDesk backup", permanently, since a backup is never
/// rewritten. A hand-listed census in prose is what missed it,
/// and prose is what this replaces (architect review,
/// 2026-08-20): the next reader arrives before its test does.
///
/// It lives in the GUI test target purely because `SourceScan`
/// does; it scans `Sources/KiwiDeskCore`.
@Suite("Config migration routing")
struct ConfigMigrationRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// The top-level shapes a config FILE decodes into. Nested
    /// `container.decode` calls inside an `init(from:)` are not
    /// file readers and are not the subject here.
    private let fileShapes = [
        "Profile.self", "SetupBundle.self", "GuiConfig.self",
    ]

    /// Every file that decodes one of those shapes, and whether
    /// it must route. `true` = must name
    /// `ConfigMigration.migrated`; `false` = exempt, with the
    /// reason recorded beside it. **This map is the census** —
    /// the rule files point here rather than restating it.
    private let readers: [String: Bool] = [
        "Profiles/ProfileManager.swift": true,
        // A bundle carries `[Profile]` inline, so it reads the
        // same shape from a file this app wrote earlier.
        "App/KiwiCore+Backup.swift": true,
        // EXEMPT, and not by oversight: `GuiConfig.encode` writes
        // only the spaces, rules, bindings and layers, and
        // `CodingKeys` has no `settings` case at all, so no
        // sidecar this app has written can carry a migratable
        // value. The day it persists `settings`, this entry flips
        // to `true` and this suite is what says so.
        "Config/GuiConfigStore.swift": false,
    ]

    @Test("Every config-file reader routes through the migration")
    func readersRouteThroughMigration() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        var found: [String: Bool] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard source.contains("decode("),
                fileShapes.contains(where: source.contains)
            else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            found[key] = source.contains(
                "ConfigMigration.migrated"
            )
        }
        for (file, routes) in found.sorted(by: { $0.key < $1.key }) {
            let unlisted =
                "\(file) decodes a config file shape but is not "
                + "in the census; route it through "
                + "ConfigMigration.migrated, or list it exempt "
                + "with the reason"
            #expect(
                readers[file] != nil,
                Comment(rawValue: unlisted)
            )
            #expect(
                readers[file] == routes,
                Comment(
                    rawValue:
                        "\(file) routes=\(routes) but the census "
                        + "says \(readers[file] ?? false)"
                )
            )
        }
        // The inverse: a census entry whose reader vanished is
        // unfalsifiable, and a mistyped root would otherwise pass
        // this suite vacuously.
        for (file, _) in readers {
            #expect(
                found[file] != nil,
                Comment(
                    rawValue:
                        "\(file) no longer decodes a config file "
                        + "shape — drop its census entry"
                )
            )
        }
    }

    /// `content` is a bar-content key and nothing else.
    ///
    /// `ConfigMigration`'s walk rewrites by KEY at any depth, and
    /// `readBackup` runs it across a whole `SetupBundle` — so a
    /// `content` CodingKey added to any other config type would
    /// put a value the walk was never scoped to inside its reach.
    /// The docstring used to assert this as a fact about the
    /// tree; a fact about the tree is true the day it is written
    /// (rule-authoring.md).
    @Test("Only the two bar styles declare a `content` key")
    func contentKeyStaysABarKey() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        // Deliberately a broad needle — `case content` anywhere
        // — so it fails CLOSED on a new declaration and the entry
        // has to state which kind it is. Two are CodingKeys and
        // therefore JSON keys the walk can reach; the third is a
        // command verb that never reaches a file.
        let allowed: Set<String> = [
            // The global bar style's JSON key...
            "Layouts/AppBarStyle+Coding.swift",
            // ...and a layout's override, one level down, which
            // is why the walk rewrites by key at any depth.
            "Layouts/LayoutAppBar.swift",
            // NOT a CodingKey: `AppBarCommandSetting.content` is
            // the `app_bar.set_content` verb, an in-memory
            // command payload. It is never serialized as a key,
            // so the walk cannot reach it.
            "Commands/AppBarCommandSetting.swift",
        ]
        var declaring: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard source.occurrences(of: "case content") > 0
            else { continue }
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            declaring.insert(key)
        }
        #expect(
            declaring == allowed,
            Comment(
                rawValue:
                    "`content` declarations: "
                    + "\(declaring.sorted()) — a new CodingKey "
                    + "owes ConfigMigration's walk a path, or "
                    + "this map a narrower home; a non-key case "
                    + "just needs its entry and its reason"
            )
        )
    }
}
