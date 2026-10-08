import Foundation
import Testing

/// The Looks picture inks an idle item on BOTH bars from the one
/// `idleInk` the live bar's `KiwiShelf.idleItemColor` answers
/// (#1938): a strip that spelled the item colour again would show
/// the App Bar brighter than the bar the user gets.
@Suite("Palette scene idle ink")
struct PaletteSceneIdleInkTests {
    private static let file =
        "Sources/KiwiDesk/Settings/Components/Looks/"
        + "PaletteSceneThumbnail+Panel.swift"

    private func strip(_ name: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.file)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "private var \(name): some View",
                in: text
            ),
            Comment(rawValue: "no `\(name)` to scan")
        )
        return body.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("both strips draw their idle items in the one idle ink")
    func idleItemsTakeTheIdleInk() throws {
        for name in ["spaceBarStrip", "appBarStrip"] {
            let body = try strip(name)
            #expect(body.contains("item(idleInk)"), "\(name)")
            // Every plain `item(` is the idle ink or the active
            // colour; any other first argument re-derives ink.
            let items = body.components(separatedBy: "item(").count - 1
            let idle =
                body.components(separatedBy: "item(idleInk)")
                .count - 1
            let active =
                body.components(
                    separatedBy: "item(color(\"kiwishelf.active_item_color\")"
                ).count - 1
            let front =
                body.components(
                    separatedBy: "item(color(\"space_bar.focused_item_color\")"
                ).count - 1
            #expect(items == idle + active + front, "\(name)")
        }
    }
}
