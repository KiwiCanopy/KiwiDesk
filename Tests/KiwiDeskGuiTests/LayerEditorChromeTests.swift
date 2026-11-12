import Foundation
import Testing

/// The layer editor's Delete Layer… keeps its red inside a popover
/// (#3263 amendment): the Settings window tints its content with
/// the accent, which replaces the colour a destructive role draws,
/// so the button names the danger tint itself.
@Suite("Layer editor chrome (#3263)")
struct LayerEditorChromeTests {
    @Test("Delete Layer… is tinted red, not the accent")
    func deleteKeepsItsRed() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/LayerEditorPopover.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        let head = "Button(LayerEditorWords.deleteLayer,role:.destructive)"
        let start = try #require(source.range(of: head))
        // The button's own chain: up to the footer's spacer after it.
        let tail = source[start.upperBound...]
        let end = try #require(tail.range(of: "Spacer("))
        let chain = tail[..<end.lowerBound]
        #expect(chain.contains(".buttonStyle(.bordered)"))
        #expect(chain.contains(".tint(SettingsTheme.danger)"))
    }
}
