import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf crossing's scoping clause (#1517). Its walk reaches
/// the bar groups by PATH — a settings root's `space_bar` and
/// `app_bar`, and the `app_bar` under `layout.monocle` /
/// `layout.scroll` — while its textual edit strips EVERY flat
/// `"space_bar"` / `"app_bar"` object in the file, by key. That
/// is safe exactly while those are the only places the keys are
/// stored: a further declarer sends the edit past the walk, and
/// the envelope's re-parse compare then falls back to
/// re-serializing the whole file — the Double drift the surgical
/// path exists to avoid (profiles.md ▸ a textual edit by KEY
/// owes the key a declarer census).
@Suite("Config migration routing — the shelf crossing")
struct ConfigMigrationShelfRoutingTests {
    @Test("The bar group keys keep their declarers")
    func barGroupKeysStayScoped() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        // Where the keys are STORED: the settings root and the
        // two bar-hosting layouts, then the files that only name
        // them — the migration steps, the palette apply and the
        // API namespace tables.
        let allowed: Set<String> = [
            "Tiling/TilingSettings+Coding.swift",
            "Layouts/MonocleParams.swift",
            "Layouts/LayoutParams.swift",
            "Config/ConfigMigration+GlassDefault.swift",
            "Config/ConfigMigration+KiwiShelf.swift",
            "Appearance/ColorPalette+Apply.swift",
            "Appearance/ColorPaletteKeys.swift",
            "Commands/Reference/APIReference.swift",
            "Commands/Reference/APIReference+Records.swift",
        ]
        var declarers: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard
                source.contains("\"app_bar\"")
                    || source.contains("\"space_bar\"")
            else { continue }
            declarers.insert(
                file.path.hasPrefix(prefix)
                    ? String(file.path.dropFirst(prefix.count))
                    : file.path
            )
        }
        #expect(
            declarers == allowed,
            Comment(
                rawValue:
                    "`app_bar` / `space_bar` spelled in: "
                    + "\(declarers.sorted()) — a new stored bar "
                    + "group sends the shelf crossing's textual "
                    + "edit past its walk, or this map owes it an "
                    + "entry"
            )
        )
    }
}
