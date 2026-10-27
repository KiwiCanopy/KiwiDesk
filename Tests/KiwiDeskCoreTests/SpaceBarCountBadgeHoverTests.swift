import AppKit
import Testing

@testable import KiwiDeskCore

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
        #expect(abs(badge.alphaValue - dim) < 0.01)
        #expect(view.appViews[0].alphaValue == 1)
    }

    @Test("Hovering the glyph brings its badge to full")
    func hoverFillsTheBadge() throws {
        let view = item(active: true)
        let target = try #require(view.glyphTargets.first)
        view.hoveredTarget = target
        view.restyle()
        #expect(view.badgeViews.first?.alphaValue == 1)
    }

    @Test("An unfocused app and another Space keep their ladder")
    func othersKeepTheirLadder() throws {
        let active = item(active: true)
        let unfocused = try #require(active.badgeViews.last)
        #expect(
            abs(unfocused.alphaValue - active.style.activeDimFactor) < 0.01
        )
        let other = item(active: false)
        let away = try #require(other.badgeViews.first)
        #expect(abs(away.alphaValue - other.style.dimFactor) < 0.01)
    }

    /// A drag over the chip lifts the badge with the rest of the
    /// ladder.
    @Test("A drag hover lifts the focused badge")
    func dragLiftsTheBadge() throws {
        let view = item(active: true)
        view.isDragHovered = true
        view.restyle()
        #expect(view.badgeViews.first?.alphaValue == 1)
        // A drag over another glyph lifts it too.
        view.hoveredTarget = view.glyphTargets.last
        view.restyle()
        #expect(view.badgeViews.first?.alphaValue == 1)
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
        #expect(view.overflowBadge.alphaValue == 1)
    }
}
