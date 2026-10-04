import AppKit
import Testing

@testable import KiwiDeskCore

/// **A bar render that changes no app list mints no view**
/// (#1942). A Space switch re-renders every item with its active
/// state flipped; the item reuses its glyph and badge views slot
/// by slot, and mints a state badge only for an app wearing that
/// state. Identity is pinned rather than an `addSubview` count,
/// since a same-parent re-add fires no view hook (#1315).
@Suite("Space Bar item view reuse (#1942)")
@MainActor
struct SpaceBarItemReuseTests {
    private static func app(
        _ id: UInt32,
        glyph: String? = nil,
        sticky: Bool = false,
        floating: Bool = false,
        scope: StickyScope = .none
    ) -> SpaceBarItemView.App {
        var app = SpaceBarItemView.App(
            name: "App\(id)",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: glyph,
            focused: id == 1,
            count: Int(id),
            windows: [WindowID(id)]
        )
        app.sticky = sticky
        app.floating = floating
        app.stickyScope = scope
        return app
    }

    private static func configure(
        _ view: SpaceBarItemView,
        apps: [SpaceBarItemView.App],
        active: Bool,
        space: String = "1",
        badges: Bool = true
    ) {
        var style = SpaceBarLook()
        style.stickyBadge = badges
        view.configure(
            identity: .space(SpaceID(space)),
            spaceGlyph: .text("1", tinted: true),
            apps: apps,
            active: active,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
    }

    /// Elementwise identity, computed outside `#expect`: written
    /// inline, `elementsEqual(_:by: ===)` passed on false
    /// (guard-prover, Testing 2084).
    static func same(_ a: [NSView?], _ b: [NSView?]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0 === $1 }
    }

    private static func view() -> SpaceBarItemView {
        SpaceBarItemView(frame: CGRect(x: 0, y: 0, width: 200, height: 28))
    }

    @Test("A render flipping only the active state keeps every subview")
    func switchKeepsViews() {
        let view = Self.view()
        let apps = [
            Self.app(1), Self.app(2, glyph: "a"),
            Self.app(3, sticky: true, floating: true),
        ]
        Self.configure(view, apps: apps, active: true)
        let before = view.subviews
        let glyphs = view.appViews
        let badges = view.badgeViews
        let sticky = view.stickyBadgeViews
        let floating = view.floatingBadgeViews
        Self.configure(view, apps: apps, active: false)
        let keepsSubviews = Self.same(view.subviews, before)
        let keepsGlyphs = Self.same(view.appViews, glyphs)
        let keepsBadges = Self.same(view.badgeViews, badges)
        let keepsSticky = Self.same(view.stickyBadgeViews, sticky)
        let keepsFloating = Self.same(view.floatingBadgeViews, floating)
        #expect(keepsSubviews)
        #expect(keepsGlyphs)
        #expect(keepsBadges)
        #expect(keepsSticky)
        #expect(keepsFloating)
    }

    @Test("A state badge stands only on an app wearing that state")
    func stateBadgesOnlyWhereWorn() {
        let view = Self.view()
        Self.configure(
            view,
            apps: [
                Self.app(1), Self.app(2, sticky: true),
                Self.app(3, floating: true),
            ],
            active: true
        )
        #expect(
            view.stickyBadgeViews.map { $0 != nil } == [false, true, false]
        )
        #expect(
            view.floatingBadgeViews.map { $0 != nil } == [false, false, true]
        )
        let marks = view.subviews.filter { $0 is StateBadgeView }
        #expect(marks.count == 2)
    }

    @Test("A glyph changing kind or an app leaving retires its views")
    func changedAppsRetireViews() throws {
        let view = Self.view()
        Self.configure(
            view,
            apps: [Self.app(1), Self.app(2, sticky: true), Self.app(3)],
            active: true
        )
        let kept = try #require(view.appViews.first)
        let departed = try #require(view.appViews.last)
        let departedBadge = try #require(view.badgeViews.last)
        let sticky = try #require(view.stickyBadgeViews[1])
        Self.configure(
            view,
            apps: [Self.app(1, glyph: "a"), Self.app(2)],
            active: true
        )
        #expect(view.appViews.count == 2)
        #expect(view.appViews[0] is NSTextField)
        #expect(kept.superview == nil)
        #expect(departed.superview == nil)
        #expect(departedBadge.superview == nil)
        let text = view.appViews[0]
        Self.configure(view, apps: [Self.app(1), Self.app(2)], active: true)
        #expect(view.appViews[0] is NSImageView)
        #expect(text.superview == nil)
        #expect(sticky.superview == nil)
        #expect(view.stickyBadgeViews.allSatisfy { $0 == nil })
        #expect(view.appViews.allSatisfy { $0.superview === view })
        #expect(view.badgeViews.allSatisfy { $0.superview === view })
        #expect(
            view.subviews.filter { $0 is StateBadgeView }.isEmpty
        )
    }

    @Test("A reused sticky badge takes its app's new scope")
    func reusedBadgeTakesTheScope() throws {
        let view = Self.view()
        Self.configure(
            view,
            apps: [Self.app(1, sticky: true, scope: .global)],
            active: true
        )
        let badge = try #require(view.stickyBadgeViews[0])
        Self.configure(
            view,
            apps: [Self.app(1, sticky: true, scope: .display)],
            active: true
        )
        #expect(view.stickyBadgeViews[0] === badge)
        #expect(badge.symbolName == StickyStyle.displaySymbolName)
        let drawn = try #require(badge.symbol.image)
        let wanted = try #require(
            NSImage(
                systemSymbolName: StickyStyle.displaySymbolName,
                accessibilityDescription: nil
            )
        )
        #expect(drawn.tiffRepresentation == wanted.tiffRepresentation)
        #expect(StickyStyle.displaySymbolName != StickyStyle.symbolName)
    }

    @Test("A reused slot takes its new app's icon and count")
    func reusedSlotTakesNewContent() throws {
        let view = Self.view()
        Self.configure(view, apps: [Self.app(1), Self.app(2)], active: true)
        let image = try #require(view.appViews[1] as? NSImageView)
        let badge = view.badgeViews[1]
        var next = Self.app(5)
        next.windows = [WindowID(2)]
        Self.configure(view, apps: [Self.app(1), next], active: true)
        #expect(view.appViews[1] === image)
        #expect(image.image === next.icon)
        #expect(view.badgeViews[1] === badge)
        #expect(badge.stringValue == "5")
        #expect(!badge.isHidden)
    }

    @Test("A slot handed another Space re-mints its views")
    func otherSpaceRemints() throws {
        let view = Self.view()
        Self.configure(view, apps: [Self.app(1)], active: true)
        let glyph = try #require(view.appViews.first)
        Self.configure(view, apps: [Self.app(1)], active: true, space: "2")
        #expect(view.appViews.first !== glyph)
        #expect(glyph.superview == nil)
    }

    @Test("With the badge switch off no state badge is minted")
    func switchOffMintsNoBadge() {
        let view = Self.view()
        Self.configure(
            view,
            apps: [Self.app(1, sticky: true, floating: true)],
            active: true,
            badges: false
        )
        #expect(view.stickyBadgeViews == [nil])
        #expect(view.floatingBadgeViews == [nil])
    }

    @Test("An app leaving with a state badge takes its badge along")
    func departingBadgeLeaves() throws {
        let view = Self.view()
        Self.configure(
            view,
            apps: [Self.app(1), Self.app(2, sticky: true, floating: true)],
            active: true
        )
        let sticky = try #require(view.stickyBadgeViews[1])
        let floating = try #require(view.floatingBadgeViews[1])
        Self.configure(view, apps: [Self.app(1)], active: true)
        #expect(sticky.superview == nil)
        #expect(floating.superview == nil)
    }
}
