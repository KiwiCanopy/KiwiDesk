import Foundation
import Testing

/// The layer editor's Delete Layer… keeps its red inside a popover
/// (#3263 amendment): an action chip, whose face draws a
/// destructive role's label red whatever the window's accent
/// (#3630).
@Suite("Layer editor chrome (#3263)")
struct LayerEditorChromeTests {
    @Test("Delete Layer… is a destructive action chip")
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
        #expect(chain.contains(".settingsActionButton()"))
        #expect(!chain.contains(".buttonStyle(.bordered)"))
    }
}
