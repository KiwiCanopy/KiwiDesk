import Foundation
import Testing

/// A bar's visibility has one reader and one write door (#761):
/// `TilingSettings.visibility(of:)` and `setVisibility(_:of:)`,
/// beside the fields in the bar styles and their coding. A raw
/// read elsewhere could fold two linked bars apart again, which is
/// the layout drift the ruling closed. Residue: a needle is one
/// spelling, so an access split across lines or through a local
/// binding passes; that half is review's.
@Suite("Bar visibility seam (#761)")
struct BarVisibilitySeamTests {
    /// Files that may name a bar style's stored visibility: the
    /// one reader and door, and the Settings files that spell its
    /// path. A setter's `apply(to:)` writes nothing for it.
    private static let allowed: [String: String] = [
        "TilingSettings+Shelf.swift": "the reader and the door",
        // A ↺ puts the baseline's stored pair back, which was
        // one answer already (#792).
        "SettingsRevertRegister+Settings1.swift": "the App Bar's ↺",
        "SettingsRevertRegister+Settings3.swift": "the Space Bar's ↺",
        // A census row's id spells its path, a string (#678).
        "SettingKey+SpaceBar.swift": "the census id",
        "SettingKey+AppBar.swift": "the census id",
    ]

    private static let needles = [
        "spaceBarStyle.visibility", "appBarStyle.visibility",
        "style.visibility",
    ]

    @Test("Both trees read a bar's visibility only through the door")
    func oneReader() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        // Settings writes through the door too (the ruling's
        // rows).
        let files =
            try SourceScan.swiftSources(
                under: repo.appendingPathComponent("Sources/KiwiDeskCore")
            )
            + SourceScan.swiftSources(
                under: repo.appendingPathComponent("Sources/KiwiDesk")
            )
        var hits: [String: Int] = [:]
        var scanned = 0
        for file in files {
            scanned += 1
            let name = file.lastPathComponent
            if name.hasPrefix("SpaceBarStyle")
                || name.hasPrefix("AppBarStyle")
            {
                continue
            }
            let source = try SourceScan.strippedSource(at: file)
            let count = Self.needles.reduce(0) {
                $0 + source.components(separatedBy: $1).count - 1
            }
            if count > 0 { hits[name] = count }
        }
        #expect(scanned > 100)
        let strays = hits.keys.filter { Self.allowed[$0] == nil }
        #expect(
            strays.isEmpty,
            "raw visibility read outside the door: \(strays.sorted())"
        )
        for file in Self.allowed.keys {
            #expect(hits[file] != nil, "\(file) no longer reads it")
        }
    }

    @Test("Both verbs write through the door")
    func verbsTakeTheDoor() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/Commands/"
                        + "KiwiCore+AppBarCommands.swift"
                )
        )
        #expect(
            source.components(
                separatedBy: "tiler.settings.setVisibility("
            ).count == 3
        )
    }
}
