import Foundation
import Testing

/// "Which window holds the system focus" is answered for a bar in
/// ONE place, `KiwiCore.barFocus(on:)` (#2063): the glyph tint,
/// the `+n` disc, the peek's check, the click's cycle and the
/// window menu's state read it, so a playing Monocle flip's owed
/// focus cannot name one window on the glyph and another in its
/// list. The strip's centring reads `lastFocused` for a different
/// question — which app the chip shows — and is its one exemption.
@Suite("Bar focus seam")
struct BarFocusSeamTests {
    private static let app = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore/App")

    private static func source(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: app.appendingPathComponent(file)
        )
    }

    private static func body(
        _ declaration: String,
        in file: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(
                after: declaration,
                in: try source(file)
            )
        )
    }

    @Test("the bar lists read the focus through barFocus alone")
    func oneFocusReading() throws {
        let raw = "state.workspaces.lastFocused"
        let peek = try Self.source("KiwiCore+BarPeek.swift")
        let focus = try Self.body(
            "func barFocus(",
            in: "KiwiCore+BarPeek.swift"
        )
        #expect(peek.occurrences(of: raw) == 1)
        #expect(focus.contains(raw))
        #expect(focus.contains("pendingMonocleFocus?.to"))
        let click = try Self.source("KiwiCore+SpaceBarClick.swift")
        #expect(click.occurrences(of: raw) == 0)
        let items = try Self.source("KiwiCore+SpaceBarItems.swift")
        let anchors = try Self.body(
            "func stripAnchors(",
            in: "KiwiCore+SpaceBarItems.swift"
        )
        #expect(items.occurrences(of: raw) == 1, "the strip's centring")
        #expect(anchors.contains(raw))
        #expect(items.occurrences(of: "barFocus(on: space.id)") == 2)
        for (name, file) in [
            ("func barPeekContent(", "KiwiCore+BarPeek.swift"),
            ("func glyphCycleTarget(", "KiwiCore+BarPeek.swift"),
            ("func spaceBarMenuRows(", "KiwiCore+SpaceBarClick.swift"),
        ] {
            #expect(
                try Self.body(name, in: file).contains("barFocus(on:"),
                "\(name) reads the one focus"
            )
        }
    }
}
