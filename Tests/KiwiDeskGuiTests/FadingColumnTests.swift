import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// A vertical KiwiHub list fades its top or bottom edge only while
/// items lie past it, and a keyboard reveal lands clear of the
/// fade (#3164, owner 2026-11-11): the Desktops side's screen rows
/// and each Desktop's Space lines.
@Suite("KiwiHub column fade (#3164)")
struct FadingColumnTests {
    @Test("a vertical list fades only where items lie past it")
    func verticalCuts() {
        // Ten 36 pt lines in a 120 pt column, no margin.
        let content: CGFloat = 360
        func cut(_ offset: CGFloat) -> (Bool, Bool) {
            let cut = EdgeFade.cuts(
                offset: offset,
                content: content,
                viewport: 120,
                inset: 0
            )
            return (cut.start, cut.end)
        }
        #expect(cut(0) == (false, true))
        #expect(cut(-100) == (true, true))
        #expect(cut(120 - content) == (true, false))
        // Overflowing, the margin shifts the content: at rest it
        // starts a fade's depth down; at the end it stops one short.
        #expect(cut(EdgeFade.depth) == (false, true))
        #expect(cut(120 - EdgeFade.depth - content) == (true, false))
    }

    @Test("the Desktops side's vertical lists fade through FadingColumn")
    func desktopsListsFade() throws {
        let jump = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/KiwiDesk/Jump")
        func read(_ name: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: jump.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
            .filter { !$0.isWhitespace }
        }
        let side = try read("DesktopsSideView.swift")
        #expect(side.contains("FadingColumn(selected:state.place?.screen,"))
        #expect(side.contains("row($0,geometry).id($0)"))
        let card = try read("DesktopCardView.swift")
        #expect(card.contains("FadingColumn(selected:selectedLine)"))
        #expect(card.contains("line($0).id($0)"))
        for source in [side, card] {
            #expect(source.occurrences(of: "ScrollView(") == 0)
        }
        let column = try read("FadingColumn.swift")
        #expect(column.contains("EdgeFade.cuts(offset:offset,"))
        #expect(column.contains("viewport:height,inset:inset)"))
        #expect(column.contains(".padding(.vertical,inset)"))
        #expect(
            column.contains(
                ".contentMargins(.vertical,overflows?fade:0,"
                    + "for:.scrollContent)"
            )
        )
        #expect(column.contains(".coordinateSpace(.named(space))"))
        #expect(column.contains("@Stateprivatevarspace=UUID()"))
        #expect(column.contains("geometry.frame(in:.named(space))"))
        #expect(column.contains("offset=frame.minY"))
        #expect(column.contains("contentHeight=frame.height"))
        #expect(column.contains("$0.size.height}action:{height=$0}"))
        #expect(column.contains(".mask(mask)"))
        #expect(
            column.contains(
                ".onChange(of:selected){reveal(proxy,animated:true)}"
            )
        )
        #expect(
            column.contains(
                ".onChange(of:overflows){reveal(proxy,animated:false)}"
            )
        )
        #expect(column.contains("proxy.scrollTo(selected)"))
        #expect(column.occurrences(of: ".frame(height:fade)") == 2)
    }

    @Test("a short viewport takes a shallower fade")
    func shallowFade() {
        #expect(EdgeFade.depth(viewport: 200) == EdgeFade.depth)
        #expect(EdgeFade.depth(viewport: 38) == 9.5)
        #expect(EdgeFade.depth(viewport: 0) == 0)
        // Half the viewport stays clear between the two fades.
        for viewport: CGFloat in [20, 38, 60, 80, 120] {
            #expect(2 * EdgeFade.depth(viewport: viewport) <= viewport / 2)
        }
    }
}
