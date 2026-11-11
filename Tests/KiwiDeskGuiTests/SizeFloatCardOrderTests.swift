import Foundation
import Testing

@testable import KiwiDesk

/// Shortcuts & Gestures ▸ Size & float (#3160): sticky under float,
/// the layouts caption under the Maximize rows, and the Tiling off
/// block closing the card behind a rule, its key row first. The
/// order list is walked by a `ForEach`, but the block and the
/// caption are placed by the group's switch, so both halves are
/// pinned. Source scans only; no renders.
@Suite("Size & float card order (#3160)")
struct SizeFloatCardOrderTests {
    private static let folder =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"

    private static func squashed(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(folder + name)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("sticky follows float; the Tiling off block closes the card")
    func order() throws {
        let rows = ShortcutsRowOrder.sizeAndFloatAtRest
        let float = try #require(
            rows.firstIndex(of: .shortcuts(.toggleFloating))
        )
        #expect(rows[float + 1] == .shortcuts(.toggleSticky))
        #expect(
            Array(rows.suffix(4)) == [
                .shortcuts(.toggleTiling),
                .behaviour(.tilingStart),
                .behaviour(.tilingOffHidesBorders),
                .behaviour(.tilingOffHidesBars),
            ]
        )
    }

    @Test("the block draws the key under its header, its rows under it")
    func blockWiring() throws {
        let group = try Self.squashed("KeybindingGroups.swift")
        #expect(
            group.contains(
                "case.shortcuts(.toggleTiling):"
                    + "TilingOffRows(model:model){family}"
            )
        )
        let rows = try Self.squashed("TilingOffRows.swift")
        let body = try #require(
            SourceScan.declarationBody(after: "varbody:someView", in: rows)
        )
        let rule = try #require(body.range(of: "SettingsTheme.hairlineSubtle"))
        let title = try #require(body.range(of: "Text(TilingOffWords.title)"))
        let key = try #require(body.range(of: ".isHeader)key"))
        let start = try #require(body.range(of: "startRow"))
        #expect(rule.upperBound <= title.lowerBound)
        #expect(title.upperBound <= key.lowerBound)
        #expect(key.upperBound <= start.lowerBound)
    }

    @Test("the layouts caption closes the Maximize rows, not the card")
    func captionUnderMaximize() throws {
        let group = try Self.squashed("KeybindingGroups.swift")
        let width = try #require(
            group.range(of: "case.shortcuts(.maximizeWidth):")
        )
        let next = try #require(
            group[width.upperBound...].range(of: "default:")
        )
        #expect(
            group[width.upperBound..<next.lowerBound]
                .contains("Text(sizeFloatCaption)")
        )
        #expect(group.occurrences(of: "Text(sizeFloatCaption)") == 1)
    }
}
