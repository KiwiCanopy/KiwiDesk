import Foundation
import Testing

@testable import KiwiDesk

/// A Desktop's title under the pointer rings its Desktop's card —
/// a column with separate Spaces, a row with shared Desktops — and
/// keeps the title plain (#3484, ruling C2, amended by #3602): the
/// selection's fill stays the selection's alone (#1173). The ✓
/// beside the shown Desktop keeps its own ink at full strength,
/// never the accent (#3210).
@Suite("Desktops title hover rings the card (#3484, #3602)")
struct DesktopTitleHoverTests {
    private func card() throws -> String {
        try source("DesktopCardView")
    }

    private func source(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/\(name).swift"
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

    @Test("the card draws the ring while its title is hovered")
    func cardRings() throws {
        let source = try card()
        let body = try run(
            source,
            from: "varbody:someView{",
            to: "privatevarlines"
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
                "iftitled,pointer.lifts(titleTarget,selected:false){"
                    + "RoundedRectangle(cornerRadius:8)"
                    + ".strokeBorder(paint.selection,"
            )
        )
        #expect(!ring.contains(".fill("))
    }

    @Test("a shared Desktop's row draws the ring for its header")
    func rowRings() throws {
        let row = try source("DesktopRowView")
        let body = try run(
            row,
            from: "varbody:someView{",
            to: "privatevarlabel"
        )
        #expect(
            body.contains(
                ".frame(height:height,alignment:.top)"
                    + ".overlay{ring}"
            )
        )
        let ring = try run(
            row,
            from: "privatevarring:someView{",
            to: ".allowsHitTesting(false)"
        )
        #expect(
            ring.contains(
                "lettarget=DesktopRowHeaderView.target(state,index)"
                    + "ifpointer.lifts(target,selected:false){"
                    + "RoundedRectangle(cornerRadius:8)"
                    + ".strokeBorder(paint.selection,"
            )
        )
        #expect(!ring.contains(".fill("))
        let header = try source("DesktopRowHeaderView")
        #expect(
            header.contains(
                ".desktopsHover(Self.target(state,index),pointer)"
            )
        )
        #expect(!header.contains("rowHover"))
        #expect(!header.contains(".fill("))
        #expect(!header.contains(".background"))
        #expect(!header.contains("pointer.lifts("))
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
        let header = try run(
            try source("DesktopRowHeaderView"),
            from: "Image(systemName:\"checkmark.circle.fill\")",
            to: ".accessibilityLabel(DesktopsText.shown)"
        )
        #expect(header.contains(".foregroundStyle(.primary)"))
        #expect(!header.contains("paint.selection"))
        #expect(!header.contains("SettingsTheme.accent"))
    }
}
