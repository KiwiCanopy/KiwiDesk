import AppKit
import Testing

@testable import KiwiDeskCore

/// **A steady-state Space Bar render reparents nothing** (#1315).
///
/// With `plain` + glass + `show_front_app` and no overflow, every
/// render added the five front-app views to the item container
/// and the hug arm then added them back into the glass run — ten
/// `addSubview` calls inside an `NSGlassEffectView` subtree for
/// views that never needed to move, each a hierarchy change the
/// glass re-evaluates. The run is now the segment's host while
/// it hugs, so a render that changes nothing adds nothing. The
/// clauses drive `SpaceBarManager.sync`, so the arm under test
/// is the production one.
@Suite("Space Bar front-view churn (#1315)")
@MainActor
struct SpaceBarFrontViewChurnTests {
    /// Below macOS 26 no run is hosted, so the spy would count
    /// nothing and every clause would pass on that.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Counts what a render adds to the run. A same-parent
    /// `addSubview` fires no hook at all (measured) — it is a
    /// reorder, which the order clause below pins instead.
    private final class SpyRun: AppBarOverlay.FlippedView {
        var adds = 0
        override func didAddSubview(_ subview: NSView) {
            super.didAddSubview(subview)
            adds += 1
        }
    }

    /// A plain Space Bar with the front-app segment on. Three
    /// Spaces hug the fixture strip; sixty overflow it with the
    /// segment pinned, the `spanBackdrop` arm.
    private static func bar(
        spaces: Int = 3,
        glass: Bool = true
    ) -> SpaceBarManager.Bar {
        var style = SpaceBarStyle()
        style.backgroundStyle = .plain
        style.liquidGlass = glass
        style.showFrontApp = true
        let items = (1...spaces).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .text(String(n), tinted: true),
                apps: [],
                active: n == 1,
                overflow: 0,
                focusInOverflow: false
            )
        }
        return SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: items,
            frontApp: SpaceBarItemView.App(
                name: "Finder",
                icon: nil,
                glyph: nil,
                focused: true,
                count: 1
            ),
            frontWindow: WindowID(1),
            strip: barTitleStrip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private static func frontViews(
        _ overlay: SpaceBarOverlay
    ) -> [NSView] {
        [
            overlay.frontBox, overlay.frontDivider, overlay.frontIcon,
            overlay.frontGlyph, overlay.frontName,
        ]
    }

    /// The overlay after one glass-OFF render, with the spy in
    /// place of the run the first glass render would create.
    private static func spied() throws -> (
        manager: SpaceBarManager, overlay: SpaceBarOverlay, run: SpyRun
    ) {
        let manager = SpaceBarManager()
        manager.sync([bar(glass: false)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let run = SpyRun()
        overlay.glassRun = run
        return (manager, overlay, run)
    }

    @Test("A second hugged render adds nothing to the glass run")
    func steadyRenderAddsNothing() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (manager, overlay, run) = try Self.spied()
        manager.sync([Self.bar()])
        try #require(run.adds > 0, "the first glass render hosted none")
        let hosted = run.adds
        let order = run.subviews
        let frames = Self.frontViews(overlay).map(\.frame)
        manager.sync([Self.bar()])
        #expect(
            run.adds == hosted,
            "a steady render added \(run.adds - hosted) views to the run"
        )
        for view in Self.frontViews(overlay) {
            #expect(view.superview === run, "\(view) left the run")
        }
        // Identity, elementwise: a re-add into the SAME host is a
        // reorder no hook reports, and it is the attach guard's.
        #expect(
            run.subviews.count == order.count
                && zip(run.subviews, order).allSatisfy { $0 === $1 },
            "a steady render reordered the run"
        )
        // The frames of the views this style never lays out too:
        // the hug offset used to move them by the delta every
        // pass, hidden.
        #expect(
            Self.frontViews(overlay).map(\.frame) == frames,
            "the segment moved between identical renders"
        )
    }

    /// The host changes with the arm and the segment follows it:
    /// the mode change is where the guarded add has to fire, and
    /// the return to the container is what the teardown owes.
    @Test("The segment follows its host across the hosting arms")
    func segmentFollowsTheHost() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (manager, overlay, run) = try Self.spied()
        manager.sync([Self.bar()])
        let content = try #require(overlay.panel?.contentView)
        manager.sync([Self.bar(spaces: 60)])
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === content,
                "pinned segment not on the panel: \(view)"
            )
        }
        manager.sync([Self.bar()])
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === run,
                "hugged segment not in the run: \(view)"
            )
        }
        manager.sync([Self.bar(glass: false)])
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === overlay.itemContainer,
                "plain segment not in the container: \(view)"
            )
        }
    }
}
