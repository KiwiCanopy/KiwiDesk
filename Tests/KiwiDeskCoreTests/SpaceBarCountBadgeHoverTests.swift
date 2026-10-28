import AppKit
import Testing

@testable import KiwiDeskCore

/// A badge's dim tier: its number's alpha, since its disc stays
/// opaque (`BarBadgeFace`).
extension NSTextField {
    fileprivate var inkAlpha: CGFloat { textColor?.alphaComponent ?? 0 }
}

/// The focused app's count badge in the current Space rests at the
/// chip's glyph dim and comes to full under the pointer (#2650): it
/// stands for the app's other windows, unfocused behind the one in
/// front, and its fill says the glyph opens their list. The icon
/// keeps full strength; an unfocused app keeps today's ladder.
@Suite("Space Bar count badge hover (#2650)", .serialized)
@MainActor
struct SpaceBarCountBadgeHoverTests {
    init() { LiquidGlassGate.override = { false } }

    private func app(_ name: String, focused: Bool) -> SpaceBarItemView.App {
        var app = SpaceBarItemView.App(
            name: name,
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: focused,
            count: 2
        )
        app.windows = [WindowID(1), WindowID(2)]
        return app
    }

    private func item(
        active: Bool,
        after: SpaceBarStrip.Disc = .none
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [app("Brave", focused: true), app("Mail", focused: false)],
            active: active,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "",
                floating: "",
                pocket: ""
            ),
            after: after
        )
        view.layout()
        view.restyle()
        return view
    }

    @Test("The focused app's badge rests dim, its icon full")
    func focusedBadgeRestsDim() throws {
        let view = item(active: true)
        let dim = view.style.activeDimFactor
        try #require(dim < 1)
        let badge = try #require(view.badgeViews.first)
        #expect(!badge.isHidden)
        #expect(abs(badge.inkAlpha - dim) < 0.01)
        #expect(view.appViews[0].alphaValue == 1)
    }

    @Test("Hovering the glyph brings its badge to full")
    func hoverFillsTheBadge() throws {
        let view = item(active: true)
        let target = try #require(view.glyphTargets.first)
        view.hoveredTarget = target
        view.restyle()
        #expect(view.badgeViews.first?.inkAlpha == 1)
    }

    @Test("An unfocused app and another Space keep their ladder")
    func othersKeepTheirLadder() throws {
        let active = item(active: true)
        let unfocused = try #require(active.badgeViews.last)
        #expect(
            abs(unfocused.inkAlpha - active.style.activeDimFactor) < 0.01
        )
        let other = item(active: false)
        let away = try #require(other.badgeViews.first)
        #expect(abs(away.inkAlpha - other.style.dimFactor) < 0.01)
    }

    /// A drag over the chip lifts the badge with the rest of the
    /// ladder.
    @Test("A drag hover lifts the focused badge")
    func dragLiftsTheBadge() throws {
        let view = item(active: true)
        view.isDragHovered = true
        view.restyle()
        #expect(view.badgeViews.first?.inkAlpha == 1)
        // A drag over another glyph lifts it too.
        view.hoveredTarget = view.glyphTargets.last
        view.restyle()
        #expect(view.badgeViews.first?.inkAlpha == 1)
    }

    /// A `+n` disc holding the focus keeps full strength: only a
    /// glyph's count badge rests dim.
    @Test("A focused +n disc keeps full strength")
    func focusedDiscStaysFull() {
        var disc = SpaceBarStrip.Disc()
        disc.windows = [WindowID(7)]
        disc.holdsFocus = true
        let view = item(active: true, after: disc)
        #expect(!view.overflowBadge.isHidden)
        #expect(view.overflowBadge.inkAlpha == 1)
    }

    /// The disc never fades with the ladder; only its number does,
    /// `+n` and a glyph's count alike.
    @Test("A dimmed badge keeps its disc opaque")
    func dimmedDiscStaysOpaque() throws {
        var disc = SpaceBarStrip.Disc()
        disc.windows = [WindowID(7)]
        let view = item(active: false, after: disc)
        let count = try #require(view.badgeViews.first)
        for badge in [count, view.overflowBadge] {
            #expect(badge.inkAlpha < 1)
            #expect(badge.alphaValue == 1)
            #expect(badge.layer?.borderWidth == BarBadgeFace.rimWidth)
        }
    }

    /// A state badge wears the same face: its disc opaque and
    /// rimmed, its symbol on the ladder (#2722).
    @Test("A dimmed state badge keeps its disc opaque")
    func dimmedStateBadgeStaysOpaque() throws {
        var floating = app("Notes", focused: false)
        floating.floating = true
        let view = SpaceBarItemView(
            frame: NSRect(x: 0, y: 0, width: 120, height: 32)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [floating],
            active: false,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "",
                floating: "",
                pocket: ""
            )
        )
        view.layout()
        view.restyle()
        let badge = try #require(view.floatingBadgeViews.first ?? nil)
        #expect(badge.alphaValue == 1)
        #expect(abs(badge.symbol.alphaValue - view.style.dimFactor) < 0.01)
        #expect(badge.layer?.borderWidth == BarBadgeFace.rimWidth)
    }
}
