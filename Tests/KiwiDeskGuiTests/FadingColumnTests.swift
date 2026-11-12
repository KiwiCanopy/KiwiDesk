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

    @Test("KiwiHub's vertical lists fade through FadingColumn")
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
        // The Windows list takes the same column (#3249).
        let panel = try read("JumpPanelView.swift")
        #expect(
            panel.contains(
                "FadingColumn(selected:model.list.selection,"
                    + "ids:Array(model.list.results.indices),"
                    + "inset:Self.listPadding)"
            )
        )
        #expect(panel.contains(".id(index)"))
        #expect(panel.occurrences(of: "ScrollView(") == 0)
        let fading = try read("FadingScroll.swift")
        let column = try read("FadingColumn.swift")
        #expect(column.contains("FadingScroll(inset:inset){content}"))
        #expect(column.occurrences(of: "ScrollView(") == 0)
        #expect(fading.contains("EdgeFade.cuts(offset:offset,"))
        #expect(fading.contains("viewport:height,inset:inset)"))
        #expect(fading.contains(".padding(.vertical,inset)"))
        // No band: nothing reserves room at the ends (owner via
        // the ui-designer, 2026-11-11).
        #expect(fading.occurrences(of: "contentMargins") == 0)
        #expect(fading.contains(".coordinateSpace(.named(space))"))
        #expect(fading.contains("@Stateprivatevarspace=UUID()"))
        #expect(fading.contains("geometry.frame(in:.named(space))"))
        #expect(fading.contains("offset=frame.minY"))
        #expect(fading.contains("contentHeight=frame.height"))
        #expect(fading.contains("$0.size.height}action:{height=$0}"))
        #expect(fading.contains(".mask(mask)"))
        #expect(fading.contains(".background(measure)"))
        #expect(
            fading.contains(
                "privatevarfade:CGFloat{EdgeFade.depth(viewport:height)}"
            )
        )
        #expect(fading.contains("[top?.clear:.black,.black]"))
        #expect(fading.contains("[.black,bottom?.clear:.black]"))
        #expect(
            column.contains(".onAppear{reveal(proxy,from:nil,animated:false)}")
        )
        #expect(
            column.contains(
                ".onChange(of:selected){old,_inmoved=true"
                    + "reveal(proxy,from:old,animated:true)}"
            )
        )
        #expect(
            column.contains(
                "guardlettarget=Self.target(from:old,to:selected,in:ids)"
            )
        )
        #expect(column.contains("proxy.scrollTo(target)"))
        #expect(fading.occurrences(of: ".frame(height:fade)") == 2)
    }

    @Test("a list settles back to its rest once the entrance lands")
    func settlesAfterTheEntrance() throws {
        // The entrance's scale leaves a nested list a few points
        // off its rest, which faded its top at rest (#3203).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/KiwiDesk")
        func read(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
            .filter { !$0.isWhitespace }
        }
        let entrance = try read("PanelEntrance.swift")
        #expect(entrance.contains("@EntryvarpanelSettled=true"))
        #expect(entrance.contains("@Stateprivatevarsettled=false"))
        #expect(
            entrance.contains(
                ".environment(\\.panelSettled,settled||reduceMotion)"
            )
        )
        #expect(entrance.contains("completionCriteria:.removed"))
        #expect(entrance.contains("appeared=true}completion:{settled=true}"))
        // Declared, read, set in the completion: nowhere else.
        #expect(entrance.occurrences(of: "settled") == 3)
        let panel = try read("Jump/JumpPanelView.swift")
        #expect(panel.contains(".panelEntrance(presence)"))
        let column = try read("Jump/FadingColumn.swift")
        #expect(
            column.contains("@Environment(\\.panelSettled)privatevarsettled")
        )
        #expect(
            column.contains(
                ".onChange(of:settled){_,settledin"
                    + "ifsettled{settle(proxy)}}"
            )
        )
        // A key press during the entrance keeps its own place: the
        // reveal's onChange sets it (pinned above), nothing else.
        #expect(column.occurrences(of: "moved=") == 2)
        let settle: String = [
            "privatefuncsettle(_proxy:ScrollViewProxy){",
            "guard!moved,",
            "lettarget=Self.target(from:nil,to:selected,in:ids)",
            "??ids.firstelse{return}",
            "proxy.scrollTo(target,anchor:.bottom)}",
        ].joined()
        #expect(column.contains(settle))
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
