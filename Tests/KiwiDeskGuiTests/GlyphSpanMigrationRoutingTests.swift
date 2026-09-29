import Foundation
import Testing

/// `glyph_span` is a Space Bar key and nothing else, and
/// `glyph_cap` is a key nowhere at all (#1528 item 22).
///
/// `ConfigMigration`'s glyph-span step renames by KEY at any depth
/// and `readBackup` runs it across a whole `SetupBundle`, so a
/// second `glyph_cap` JSON key anywhere in the config would be
/// renamed by a step never scoped to it — the argument
/// `ConfigMigrationRoutingTests` makes for `scroll_speed`.
@Suite("Glyph span migration scope (#1528)")
struct GlyphSpanMigrationRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    @Test("the glyph-span rename stays scoped to one key")
    func glyphSpanKeyStaysUnique() throws {
        let prefix = coreRoot.path + "/"
        // The CodingKey the walk lands on, the migration's own
        // rename target, and the verb's field name — a command
        // argument, never a stored key the walk can reach.
        let allowedLive: Set<String> = [
            "Layouts/SpaceBarStyle+Coding.swift",
            "Config/ConfigMigration+GlyphSpan.swift",
            "Commands/SpaceBarCommandSetting.swift",
        ]
        // Only the migration may still name the retired key.
        let allowedRetired: Set<String> = [
            "Config/ConfigMigration+GlyphSpan.swift"
        ]
        var live: Set<String> = []
        var retired: Set<String> = []
        for file in try SourceScan.swiftSources(under: coreRoot) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            if source.contains("\"glyph_span\"") {
                live.insert(key)
            }
            if source.contains("\"glyph_cap\"") {
                retired.insert(key)
            }
        }
        #expect(!live.isEmpty)
        #expect(
            live == allowedLive,
            Comment(
                rawValue: "`glyph_span` declarations: \(live.sorted())"
                    + " — a second one owes the step a path, or this"
                    + " map a narrower home"
            )
        )
        #expect(
            retired == allowedRetired,
            Comment(
                rawValue: "`glyph_cap` still named in: "
                    + "\(retired.sorted()) — only the migration may"
            )
        )
    }
}
