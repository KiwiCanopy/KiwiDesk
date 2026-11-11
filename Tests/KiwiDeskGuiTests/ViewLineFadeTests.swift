import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// A sideways KiwiHub line fades an edge only while an item lies
/// beyond it (#3166): scrolled to an end item, a `scrollTo` leaves
/// the line's margin off the edge, which cuts nothing.
@Suite("KiwiHub line fade (#3166)")
struct ViewLineFadeTests {
    typealias L = ViewLine<Int, EmptyView>

    static let inset: CGFloat = 16
    static let width: CGFloat = 720
    /// Five 224 pt columns, their dividers and the two margins.
    static let content: CGFloat = 5 * 224 + 4 + 2 * inset

    private func cuts(_ offset: CGFloat) -> (Bool, Bool) {
        let cut = L.cuts(
            offset: offset,
            content: Self.content,
            width: Self.width,
            inset: Self.inset
        )
        return (cut.leading, cut.trailing)
    }

    @Test("at the start only the far edge fades")
    func start() {
        #expect(cuts(0) == (false, true))
    }

    @Test("the end item shown whole, its margin off the edge: no fade")
    func endItemWhole() {
        // `scrollTo` the last column: its trailing edge on the
        // viewport's, the margin beyond.
        let last = Self.width + Self.inset - Self.content
        #expect(cuts(last) == (true, false))
        // Scrolled fully to the end as well.
        #expect(cuts(Self.width - Self.content) == (true, false))
    }

    @Test("an item cut past the margin fades that edge")
    func itemCut() {
        let last = Self.width + Self.inset - Self.content
        #expect(cuts(last + 1) == (true, true))
        #expect(cuts(-Self.inset - 1).0)
        #expect(!cuts(-Self.inset).0)
    }

    @Test("the View side's and the strip's own margin cuts nothing")
    func defaultInset() {
        let inset = KeyPanelStyle.selectionInset
        let content: CGFloat = 900 + 2 * inset
        func cut(_ offset: CGFloat) -> (Bool, Bool) {
            let cut = L.cuts(
                offset: offset,
                content: content,
                width: Self.width,
                inset: inset
            )
            return (cut.leading, cut.trailing)
        }
        #expect(cut(Self.width + inset - content) == (true, false))
        #expect(cut(Self.width + inset - content + 1) == (true, true))
        #expect(cut(-inset) == (false, true))
    }

    @Test("a line that fits fades nowhere")
    func fits() {
        let cut = L.cuts(
            offset: 0,
            content: 600,
            width: Self.width,
            inset: Self.inset
        )
        #expect(!cut.leading && !cut.trailing)
    }

    @Test("the mask fades by the line's own inset")
    func maskReadsTheInset() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Sources/KiwiDesk/Jump")
            .appendingPathComponent("ViewLine.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
        #expect(source.contains("Self.cuts(offset:offset,"))
        #expect(source.contains("width:width,inset:inset)"))
        #expect(source.contains(".padding(.horizontal,inset)"))
    }

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
        #expect(side.contains("row($0,geometry).fadingTarget($0)"))
        let card = try read("DesktopCardView.swift")
        #expect(card.contains("FadingColumn(selected:selectedLine)"))
        #expect(card.contains("line($0).fadingTarget($0)"))
        for source in [side, card] {
            #expect(source.occurrences(of: "ScrollView(") == 0)
        }
        let column = try read("FadingColumn.swift")
        #expect(column.contains("EdgeFade.cuts(offset:offset,"))
        #expect(column.contains("viewport:height,inset:inset)"))
        #expect(column.contains(".padding(.vertical,inset)"))
        #expect(column.contains(".padding(.vertical,-EdgeFade.depth)"))
        #expect(column.contains("proxy.scrollTo(selected)"))
    }
}
