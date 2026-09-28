import Foundation
import KiwiDeskCore
import Testing

/// Each layout's SF Symbol has ONE home, `LayoutMode.symbol`, which
/// the Layout menu, the Settings tabs and the Space Bar's layout
/// label share (#1535): a second copy lets the menu and the bar
/// drift apart. The needles are read off `allCases`, so a new
/// mode is scanned without an edit here.
@Suite("Layout mode symbol seam")
struct LayoutModeSymbolSeamTests {
    private let home =
        "Sources/KiwiDeskCore/Models/LayoutMode+Symbol.swift"

    /// Repo-relative path → the symbols it may spell, and why.
    /// Exact both ways: a stale entry reds too.
    private let allowed: [String: (Set<String>, String)] = [
        "Sources/KiwiDesk/Settings/Components/Icons/IconCatalog.swift":
            (
                ["rectangle.split.3x1", "square.grid.3x3"],
                "user-pickable Space icons, not a mode map"
            )
    ]

    @Test("Only LayoutMode.symbol spells a layout's symbol")
    func oneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let needles = Set(LayoutMode.allCases.map(\.symbol))
        var found: [String: Set<String>] = [:]
        var scanned = 0
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            for file in files {
                scanned += 1
                let path = String(
                    file.path.dropFirst(root.path.count + 1)
                )
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = needles.filter {
                    source.contains("\"\($0)\"")
                }
                if !hits.isEmpty { found[path] = hits }
            }
        }
        #expect(scanned > 100, "the scan reached no tree")
        #expect(found[home] == needles, "the home lost a mode")
        found[home] = nil
        #expect(
            found == allowed.mapValues(\.0),
            "a layout symbol spelled outside LayoutMode.symbol"
        )
    }
}
