import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The centred strip on the chip itself (#1528 items 17, 21): a
/// leading `+n` disc with its own target ahead of the glyphs, a
/// strip that moved under the same Space walks — the glyphs it
/// carries off kept to fade under their disc — and a chip reports
/// the pointer resting on it with the strip it drew.
@Suite("Space Bar strip on the chip")
@MainActor
struct SpaceBarStripViewTests {
    private static let depth: CGFloat = 32

    private func app(_ id: UInt32) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: "App\(id)",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: 1,
            windows: [WindowID(id)]
        )
    }

    private func configure(
        _ view: SpaceBarItemView,
        drawn: ClosedRange<UInt32>,
        of count: UInt32 = 9,
        space: SpaceID = SpaceID("1"),
        layingOut: Bool = true
    ) {
        var style = SpaceBarLook()
        style.glyphGap = 0
        view.configure(
            identity: .space(space),
            spaceGlyph: .text("1", tinted: true),
            apps: drawn.map(app),
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            before: .init(
                windows: (1..<drawn.lowerBound).map(WindowID.init)
            ),
            after: .init(
                windows: ((drawn.upperBound + 1)..<(count + 1))
                    .map(WindowID.init)
            ),
            drawn: .init(
                window: Int(drawn.lowerBound - 1)..<Int(drawn.upperBound),
                count: Int(count)
            )
        )
        if layingOut { view.layout() }
    }

    private func makeView() -> SpaceBarItemView {
        let length = SpaceBarItemView.autoLength(
            appCount: 5,
            discs: 2,
            contentDepth: Self.depth,
            glyphGap: 0,
            // The item's own ends: app glyphs pad both (#1856).
            ends: SpaceBarItemView.ends(
                look: SpaceBarLook(),
                depth: Self.depth,
                first: false,
                last: false,
                leadsWithIcon: false,
                endsInIcon: true,
                lone: nil
            )
        )
        return SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: length, height: Self.depth)
        )
    }

    @Test("the leading disc sits before the glyphs with its own target")
    func leadingDiscLeads() throws {
        LocalizationManager.shared.select("en")
        let view = makeView()
        configure(view, drawn: 3...7)
        let leading = try #require(view.leadingTarget)
        let trailing = try #require(view.overflowTarget)
        // Nearest the glyphs first: the leading disc mirrors the row.
        #expect(leading.members == [WindowID(2), WindowID(1)])
        #expect(trailing.members == [WindowID(8), WindowID(9)])
        let first = try #require(view.appViews.first)
        // Within the half point a glyph's backing-aligned frame
        // rounds by, beside the disc's unrounded target.
        #expect(leading.frame.maxX <= first.frame.minX + 0.5)
        #expect(!view.leadingBadge.isHidden)
        #expect(view.leadingBadge.stringValue == "+2")
        #expect(
            leading.accessibilityLabel() == "Earlier windows not shown: 2"
        )
        #expect(
            trailing.accessibilityLabel() == "Later windows not shown: 2"
        )
    }

    /// The chip announces every window its Space holds — those
    /// behind the leading disc too, not only the drawn glyphs and
    /// the trailing disc.
    @Test("the chip counts the windows before its glyphs")
    func labelCountsTheLeadingDisc() {
        LocalizationManager.shared.select("en")
        let view = makeView()
        configure(view, drawn: 3...7)
        #expect(view.heldWindows == 9)
        #expect(
            view.accessibilityLabel() == "Space 1, windows: 9, current"
        )
    }

    /// A step forward carries the leading glyph off: it is kept
    /// for its fade while the new glyphs draw, and the walk is
    /// consumed by the layout that plays it.
    @Test("a moved strip walks and keeps the glyph it carries off")
    func movedStripWalks() {
        let view = makeView()
        configure(view, drawn: 3...7)
        let carried = view.appViews[0]
        configure(view, drawn: 4...8)
        #expect(view.leavingViews.count == 1)
        #expect(view.leavingViews.first === carried)
        #expect(carried.superview === view)
        #expect(view.pendingWalk == nil)
        #expect(view.appViews.count == 5)
    }

    /// A step back carries the trailing glyph off instead.
    @Test("a strip stepping back keeps its last glyph to fade")
    func backStepCarriesTheLast() {
        let view = makeView()
        configure(view, drawn: 4...8)
        let carried = view.appViews[4]
        configure(view, drawn: 3...7)
        #expect(view.leavingViews.count == 1)
        #expect(view.leavingViews.first === carried)
    }

    /// A window opened or closed renumbers every group, so the
    /// same indices name other apps: the chip redraws in place.
    @Test("a changed row walks nothing")
    func changedRowStays() {
        let view = makeView()
        configure(view, drawn: 3...7)
        configure(view, drawn: 4...8, of: 10)
        #expect(view.leavingViews.isEmpty)
    }

    /// The bar lays a chip out more than once per render: a pass
    /// after the walk started re-writes the final frames and the
    /// resting alphas, and must neither drop the glyph fading out
    /// nor cancel the one fading in — the walk is an offset over
    /// those values, so it plays on regardless.
    @Test("a later layout pass leaves a walk in flight")
    func laterPassKeepsTheWalk() throws {
        let view = makeView()
        configure(view, drawn: 3...7)
        let carried = view.appViews[0]
        configure(view, drawn: 4...8)
        let arriving = try #require(view.appViews.last)
        view.layout()
        #expect(carried.superview === view)
        #expect(view.leavingViews.first === carried)
        let plays = !BarMotion.isReduced
        #expect(
            (arriving.layer?.animation(forKey: "kiwi.walk.fade") != nil)
                == plays
        )
        #expect(
            (carried.layer?.animation(forKey: "kiwi.walk.fade") != nil)
                == plays
        )
    }

    /// A menu pick lays the chip out late, and a second render of
    /// the same strip can land first: it keeps the walk and the
    /// glyph it carries off rather than swapping in place.
    @Test("a repeat render before layout keeps the walk")
    func repeatRenderKeepsTheWalk() {
        let view = makeView()
        configure(view, drawn: 3...7)
        let carried = view.appViews[0]
        configure(view, drawn: 4...8, layingOut: false)
        configure(view, drawn: 4...8, layingOut: false)
        #expect(view.pendingWalk != nil)
        #expect(view.leavingViews.first === carried)
        view.layout()
        #expect(carried.superview === view)
        #expect(
            (view.appViews.last?.layer?.animation(forKey: "kiwi.walk.fade")
                != nil) == !BarMotion.isReduced
        )
    }

    /// A render while the walk plays keeps the glyph fading out;
    /// the walk's own end removes it.
    @Test("a render mid-walk keeps the fading glyph until it lands")
    func midWalkRenderKeepsTheFade() async throws {
        let view = makeView()
        configure(view, drawn: 3...7)
        let carried = view.appViews[0]
        configure(view, drawn: 4...8)
        configure(view, drawn: 4...8)
        #expect(carried.superview === view)
        // A generous guard rather than a deadline: a busy main
        // actor runs the walk's end late, never early.
        for _ in 0..<300 where carried.superview != nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(carried.superview == nil)
        #expect(view.leavingViews.isEmpty)
    }

    @Test("an unmoved strip walks nothing")
    func unmovedStripStays() {
        let view = makeView()
        configure(view, drawn: 3...7)
        configure(view, drawn: 3...7)
        #expect(view.leavingViews.isEmpty)
    }

    @Test("the chip reports the pointer with the strip it drew")
    func reportsThePointer() {
        let view = makeView()
        configure(view, drawn: 3...7)
        var reports: [(SpaceID, SpaceBarStrip.Drawn?, Bool)] = []
        view.onPointerInside = { reports.append(($0, $1, $2)) }
        view.setPointerInside(true)
        view.setPointerInside(true)
        view.setPointerInside(false)
        #expect(reports.map(\.2) == [true, false])
        #expect(reports.first?.1 == .init(window: 2..<7, count: 9))
    }

    /// Item views are reused by index: a slot that starts drawing
    /// another Space under a resting pointer reports the old
    /// Space's exit, or its hold would never release.
    @Test("a slot handed another Space reports the old one's exit")
    func identityChangeReportsExit() {
        let view = makeView()
        configure(view, drawn: 3...7)
        var reports: [(SpaceID, Bool)] = []
        view.onPointerInside = { reports.append(($0, $2)) }
        view.setPointerInside(true)
        configure(view, drawn: 3...7, space: SpaceID("2"))
        #expect(reports.map(\.0) == [SpaceID("1"), SpaceID("1")])
        #expect(reports.map(\.1) == [true, false])
        #expect(!view.pointerInside)
    }
}
