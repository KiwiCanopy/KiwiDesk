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
}
