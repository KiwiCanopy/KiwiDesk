import Foundation
import Testing

@testable import KiwiDesk

/// A Desktop's title under the pointer rings its whole column and
/// keeps the title plain (#3484, ruling C2): the selection's fill
/// stays the selection's alone (#1173). The ✓ beside the shown
/// Desktop keeps its own ink at full strength, never the accent
/// (#3210).
@Suite("Desktops title hover rings the column (#3484)")
struct DesktopTitleHoverTests {
    private func card() throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/DesktopCardView.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    /// The text between `start` and the next `end` after it.
    private func run(
        _ source: String,
        from start: String,
        to end: String
    ) throws -> String {
        let head = try #require(source.range(of: start))
        let rest = source[head.upperBound...]
        let tail = try #require(rest.range(of: end))
        return String(rest[..<tail.lowerBound])
    }

    @Test("the column draws the ring while its title is hovered")
    func columnRings() throws {
        let source = try card()
        let body = try run(
            source,
            from: "varbody:someView{",
            to: "privatevarselectedLine"
        )
        #expect(
            body.contains(
                ".frame(width:width,alignment:.top).overlay{ring}"
            )
        )
        let ring = try run(
            source,
            from: "privatevarring:someView{",
            to: "privatevartitle:someView{"
        )
        #expect(
            ring.contains(
                "ifpointer.lifts(titleTarget,selected:false){"
                    + "RoundedRectangle(cornerRadius:8)"
                    + ".strokeBorder(paint.selection,"
            )
        )
        #expect(!ring.contains(".fill("))
    }

    @Test("the title takes no ground and no hover ink")
    func titleStaysPlain() throws {
        let title = try run(
            try card(),
            from: "privatevartitle:someView{",
            to: "privatefuncclick()"
        )
        #expect(!title.contains("rowHover"))
        #expect(!title.contains(".fill("))
        #expect(!title.contains(".background"))
        #expect(!title.contains("kiwiHubRowInk("))
        #expect(!title.contains("pointer.lifts("))
    }

    @Test("the ✓ takes its own ink at full strength, never the accent")
    func checkKeepsItsInk() throws {
        let check = try run(
            try card(),
            from: "Image(systemName:\"checkmark.circle.fill\")",
            to: ".accessibilityLabel(DesktopsText.shown)"
        )
        #expect(check.contains(".foregroundStyle(.primary)"))
        #expect(!check.contains("paint.selection"))
        #expect(!check.contains("SettingsTheme.accent"))
    }
}
