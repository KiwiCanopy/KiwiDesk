import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The item-level half of #1528: a Space Bar item lays a click
/// target over every glyph and the `+n` badge, the hit test lands
/// on it wherever it lies, and a click off the targets is still the
/// chip's own Space switch.
@Suite("Space bar glyph targets")
@MainActor
struct SpaceBarGlyphTargetTests {
    private static let depth: CGFloat = 32
    private static let click = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!

    private func app(
        _ name: String,
        _ windows: [UInt32]
    ) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: name,
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: windows.count,
            windows: windows.map(WindowID.init)
        )
    }

    private func view(
        horizontal: Bool = true,
        overflow: [UInt32] = [],
        collapsed: Bool = false,
        actions: SpaceBarGlyphActions? = nil
    ) -> SpaceBarItemView {
        let apps = [app("Mail", [2, 3]), app("Web", [4])]
        let length = SpaceBarItemView.autoLength(
            appCount: apps.count,
            overflow: overflow.count,
            contentDepth: Self.depth,
            glyphGap: 0,
            ends: SpaceBarItemView.ends(
                look: SpaceBarLook(),
                depth: Self.depth,
                first: false,
                last: false,
                leadsWithIcon: false,
                endsInIcon: SpaceBarItemView.endsInIcon(
                    appCount: apps.count,
                    badged: false,
                    horizontal: true
                )
            )
        )
        let view = SpaceBarItemView(
            frame: horizontal
                ? CGRect(x: 0, y: 0, width: length, height: Self.depth)
                : CGRect(x: 0, y: 0, width: Self.depth, height: length)
        )
        view.glyphActions = actions
        var style = SpaceBarLook()
        style.glyphGap = 0
        view.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: apps,
            active: false,
            horizontal: horizontal,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            overflow: overflow.count,
            overflowWindows: overflow.map(WindowID.init),
            collapse: collapsed ? .init(windows: 3) : nil
        )
        view.layout()
        return view
    }

    /// `hitTest` takes the superview's coordinates.
    private func hit(
        _ view: SpaceBarItemView,
        _ local: CGPoint
    ) -> NSView? {
        let host = NSView(frame: view.frame)
        host.addSubview(view)
        return view.hitTest(view.convert(local, to: host))
    }

    @Test("Each glyph gets a target on its cell, in row order")
    func targetsSitOnTheCells() {
        for horizontal in [true, false] {
            let item = view(horizontal: horizontal)
            #expect(
                item.glyphTargets.map(\.members)
                    == [[WindowID(2), WindowID(3)], [WindowID(4)]]
            )
            for (target, glyph) in zip(item.glyphTargets, item.appViews) {
                let centre = CGPoint(
                    x: glyph.frame.midX,
                    y: glyph.frame.midY
                )
                #expect(target.frame.contains(centre))
            }
        }
    }

    @Test("The hit test lands on the target over the glyph views")
    func hitTestPrefersTheTarget() throws {
        let item = view()
        let web = try #require(item.glyphTargets.last)
        // A re-render re-adds the glyph views above kept targets.
        item.appViews.forEach { item.addSubview($0) }
        let centre = CGPoint(x: web.frame.midX, y: web.frame.midY)
        #expect(hit(item, centre) === web)
        let pad = CGPoint(x: 1, y: Self.depth / 2)
        // Off the targets the chip's own subtree answers, whose
        // views pass the click up to the chip's Space switch.
        let off = try #require(hit(item, pad))
        #expect(!(off is SpaceBarGlyphTarget))
        #expect(off.isDescendant(of: item))
    }

    @Test("A target sends its pick; a padding click stays the switch")
    func targetSendsItsPick() throws {
        let actions = SpaceBarGlyphActions()
        var picks: [SpaceBarGlyphPick] = []
        actions.pick = { picks.append($0) }
        let item = view(overflow: [5, 6], actions: actions)
        var switched: [SpaceID] = []
        item.onSelect = { switched.append($0) }
        let mail = try #require(item.glyphTargets.first)
        mail.mouseDown(with: Self.click)
        let more = try #require(item.overflowTarget)
        #expect(more.accessibilityPerformPress())
        #expect(picks.map(\.kind) == [.glyph, .overflow])
        #expect(
            picks.map(\.windows)
                == [[WindowID(2), WindowID(3)], [WindowID(5), WindowID(6)]]
        )
        #expect(picks.allSatisfy { $0.space == SpaceID("2") })
        #expect(switched.isEmpty)
        item.mouseDown(with: Self.click)
        #expect(switched == [SpaceID("2")])
    }

    @Test("+n has a target only while it draws")
    func overflowTargetFollowsTheBadge() throws {
        #expect(view().overflowTarget == nil)
        let item = view(overflow: [5])
        let more = try #require(item.overflowTarget)
        let badge = CGPoint(
            x: item.overflowBadge.frame.midX,
            y: item.overflowBadge.frame.midY
        )
        #expect(more.frame.contains(badge))
        #expect(view(overflow: [5], collapsed: true).overflowTarget == nil)
    }

    @Test("A render with the same +n windows keeps its target")
    func sameOverflowKeepsTheTarget() throws {
        LocalizationManager.shared.select("en")
        let item = view(overflow: [5])
        let before = try #require(item.overflowTarget)
        let rerender = { (overflow: [UInt32]) in
            item.configure(
                identity: .space(SpaceID("2")),
                spaceGlyph: .text("2", tinted: true),
                apps: [app("Mail", [2, 3]), app("Web", [4])],
                active: false,
                horizontal: true,
                style: SpaceBarLook(),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                ),
                overflow: overflow.count,
                overflowWindows: overflow.map(WindowID.init)
            )
        }
        rerender([5])
        #expect(item.overflowTarget === before)
        rerender([6])
        #expect(item.overflowTarget !== before)
        #expect(item.overflowTarget?.members == [WindowID(6)])
    }

    @Test("Every target is a VoiceOver button named by its app")
    func targetsSpeak() throws {
        LocalizationManager.shared.select("en")
        let item = view(overflow: [5])
        let buttons = item.glyphTargets.filter {
            $0.isAccessibilityElement()
                && $0.accessibilityRole() == .button
        }
        #expect(buttons.count == item.glyphTargets.count)
        #expect(
            item.glyphTargets.map { $0.accessibilityLabel() }
                == ["Mail, windows: 2", "Web"]
        )
        let more = try #require(item.overflowTarget)
        #expect(more.accessibilityLabel() == "Windows not shown: 1")
    }

    @Test("A render with the same windows keeps its targets")
    func sameWindowsKeepTheTargets() {
        let item = view()
        let before = item.glyphTargets.map(ObjectIdentifier.init)
        item.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: [app("Mail", [2, 3]), app("Web", [4])],
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(item.glyphTargets.map(ObjectIdentifier.init) == before)
        item.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: [app("Web", [4])],
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(item.glyphTargets.map(\.members) == [[WindowID(4)]])
        #expect(item.subviews.filter { $0 is SpaceBarGlyphTarget }.count == 1)
        // Same app and count, another window: a new target.
        item.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: [app("Web", [6])],
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        #expect(item.glyphTargets.map(\.members) == [[WindowID(6)]])
    }
}
