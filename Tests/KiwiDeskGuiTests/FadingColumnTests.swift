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
        // The side's own padding off an edge cuts nothing.
        let pad = DesktopsGeometry.sidePadding
        let padded = { (offset: CGFloat) -> (Bool, Bool) in
            let cut = EdgeFade.cuts(
                offset: offset,
                content: content,
                viewport: 120,
                inset: pad
            )
            return (cut.start, cut.end)
        }
        #expect(padded(-pad) == (false, true))
        #expect(padded(-pad - 1).0)
        #expect(!padded(120 + pad - content).1)
        #expect(padded(120 + pad - content + 1).1)
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
        #expect(
            side.contains(
                "FadingColumn(selected:state.place.map"
                    + "{DesktopsScrollID.screen($0.screen)},"
                    + "ids:state.overview.screens.indices"
                    + ".map(DesktopsScrollID.screen),"
                    + "inset:DesktopsGeometry.sidePadding)"
            )
        )
        #expect(
            side.contains("row($0,geometry).id(DesktopsScrollID.screen($0))")
        )
        #expect(side.contains(".id(DesktopsScrollID.desktop(screen,index))"))
        let card = try read("DesktopCardView.swift")
        #expect(
            card.contains(
                "FadingColumn(selected:selectedLine.map(lineID),"
                    + "ids:desktop.spaces.indices.map(lineID))"
            )
        )
        #expect(card.contains("line($0).id(lineID($0))"))
        for source in [side, card] {
            #expect(source.occurrences(of: "ScrollView(") == 0)
        }
        let column = try read("FadingColumn.swift")
        #expect(column.contains("EdgeFade.cuts(offset:offset,"))
        #expect(column.contains("viewport:height,inset:inset)"))
        #expect(column.contains(".padding(.vertical,inset)"))
        // No band: nothing reserves room at the ends (owner via
        // the ui-designer, 2026-11-11).
        #expect(column.occurrences(of: "contentMargins") == 0)
        #expect(column.contains(".coordinateSpace(.named(space))"))
        #expect(column.contains("@Stateprivatevarspace=UUID()"))
        #expect(column.contains("geometry.frame(in:.named(space))"))
        #expect(column.contains("offset=frame.minY"))
        #expect(column.contains("contentHeight=frame.height"))
        #expect(column.contains("$0.size.height}action:{height=$0}"))
        #expect(column.contains(".mask(mask)"))
        #expect(column.contains(".background(measure)"))
        #expect(
            column.contains(
                "privatevarfade:CGFloat{EdgeFade.depth(viewport:height)}"
            )
        )
        #expect(column.contains("[top?.clear:.black,.black]"))
        #expect(column.contains("[.black,bottom?.clear:.black]"))
        #expect(
            column.contains(".onAppear{reveal(proxy,from:nil,animated:false)}")
        )
        #expect(
            column.contains(
                ".onChange(of:selected){old,_in"
                    + "reveal(proxy,from:old,animated:true)}"
            )
        )
        #expect(
            column.contains(
                "guardlettarget=Self.target(from:old,to:selected,in:ids)"
            )
        )
        #expect(column.contains("proxy.scrollTo(target)"))
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

    @Test("a reveal scrolls to the item past the selection")
    func lookAhead() {
        typealias C = FadingColumn<Int, EmptyView>
        let ids = Array(0..<8)
        // Down: the next item; up: the one before.
        #expect(C.target(from: 2, to: 3, in: ids) == 4)
        #expect(C.target(from: 5, to: 4, in: ids) == 3)
        // A jump keeps its direction.
        #expect(C.target(from: 0, to: 5, in: ids) == 6)
        #expect(C.target(from: 7, to: 2, in: ids) == 1)
        // At an end, the item itself, which then shows whole.
        #expect(C.target(from: 6, to: 7, in: ids) == 7)
        #expect(C.target(from: 1, to: 0, in: ids) == 0)
        // Opening looks down; nothing selected reveals nothing.
        #expect(C.target(from: nil, to: 3, in: ids) == 4)
        #expect(C.target(from: 3, to: nil, in: ids) == nil)
    }
}
