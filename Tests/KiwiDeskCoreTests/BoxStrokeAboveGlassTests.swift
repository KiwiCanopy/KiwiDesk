import AppKit
import Testing

@testable import KiwiDeskCore

/// Under Boxed glass a box's border, outline and what draws over the
/// outline ride above its glass, never inside it: the glass draws
/// its key-window rim over its content, which washed the outer point
/// of either stroke white (#2595, device 2026-10-25). Both bars
/// render through their overlays; the item stays the one writer of
/// the riders' frames, keeps its own presses and, at a teardown,
/// takes the stack back in the order it was built in.
@Suite("Box strokes above the glass", .serialized)
@MainActor
struct BoxStrokeAboveGlassTests {
    private static var platformGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private let strip = CGRect(x: 0, y: 0, width: 900, height: 30)

    private func appOverlay() -> AppBarOverlay {
        var style = AppBarLook()
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        style.activeIndicator = .outline
        let overlay = AppBarOverlay()
        overlay.show(
            items: [1, 2].map { id in
                AppBarOverlay.Item(
                    id: WindowID(id),
                    name: "App",
                    text: "App",
                    icon: nil,
                    count: 2,
                    members: nil
                )
            },
            activeIndex: 0,
            strip: strip,
            style: style,
            space: SpaceID("1")
        )
        return overlay
    }

    private func spaceOverlay() -> SpaceBarOverlay {
        var style = SpaceBarLook()
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        style.activeIndicator = .outline
        style.stickyBadge = true
        let app = SpaceBarItemView.App(
            name: "App",
            icon: nil,
            glyph: nil,
            focused: true,
            count: 2,
            sticky: true
        )
        let overlay = SpaceBarOverlay()
        overlay.show(
            items: [1, 2].map { n in
                SpaceBarOverlay.Item(
                    space: SpaceID(String(n)),
                    spaceGlyph: .text(String(n), tinted: true),
                    apps: [app],
                    active: n == 1,
                    after: .none
                )
            },
            strip: strip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        return overlay
    }

    /// `riders` sit in the host of `glass`, above it and in order,
    /// framed as the item that fills the host.
    private func expectAbove(
        _ riders: [NSView],
        of item: NSView,
        glass: NSView,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let host = try #require(
            GlassBox.host(of: glass),
            sourceLocation: sourceLocation
        )
        let order = host.subviews
        var last = try #require(
            order.firstIndex(of: glass),
            sourceLocation: sourceLocation
        )
        for rider in riders {
            let index = try #require(
                order.firstIndex(of: rider),
                "a rider left inside the glass",
                sourceLocation: sourceLocation
            )
            #expect(index > last, sourceLocation: sourceLocation)
            #expect(
                rider.frame == item.bounds,
                sourceLocation: sourceLocation
            )
            last = index
        }
    }

    /// The item frames its riders: a host resize writes its glass,
    /// never them.
    private func expectHostLeavesRiders(
        _ riders: [NSView],
        glass: NSView,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let host = try #require(
            GlassBox.host(of: glass),
            sourceLocation: sourceLocation
        )
        let before = riders.map(\.frame)
        host.setFrameSize(
            NSSize(width: host.bounds.width + 20, height: host.bounds.height)
        )
        #expect(
            riders.map(\.frame) == before,
            sourceLocation: sourceLocation
        )
    }

    /// Back in `item`: the border at the bottom, the outline clip and
    /// what draws over it on top.
    private func expectHome(
        _ item: NSView,
        border: NSView,
        clip: NSView,
        above: NSView,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let order = item.subviews
        #expect(order.first === border, sourceLocation: sourceLocation)
        #expect(
            Array(order.suffix(2)) == [clip, above],
            sourceLocation: sourceLocation
        )
    }

    @Test("An App Bar box's stroke stack rides above its glass")
    func appBarStrokesAbove() throws {
        try #require(Self.platformGlass)
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = appOverlay()
        #expect(overlay.boxGlasses.count == 2)
        for (item, glass) in zip(overlay.itemViews, overlay.boxGlasses) {
            #expect(GlassPlate.holds(glass, item))
            try expectAbove(item.strokes, of: item, glass: glass)
        }
        let active = try #require(overlay.itemViews.first)
        #expect(!active.accent.isHidden)
        // The count badge draws over the outline, glass or not.
        #expect(!active.badge.isHidden)
        #expect(active.badge.superview === active.aboveOutline)
        try expectHostLeavesRiders(
            active.strokes,
            glass: try #require(overlay.boxGlasses.first)
        )
        // Every press inside the item is the item's.
        let centre = CGPoint(x: active.bounds.midX, y: active.bounds.midY)
        let inParent = active.convert(centre, to: active.superview)
        #expect(active.hitTest(inParent) === active)

        overlay.teardownBoxGlasses()

        expectHome(
            active,
            border: active.boxBorder,
            clip: active.accentClip,
            above: active.aboveOutline
        )
    }

    @Test("A Space Bar box's stroke stack rides above its glass")
    func spaceBarStrokesAbove() throws {
        try #require(Self.platformGlass)
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = spaceOverlay()
        #expect(overlay.boxGlasses.count == 2)
        for (item, glass) in zip(overlay.itemViews, overlay.boxGlasses) {
            #expect(GlassPlate.holds(glass, item))
            try expectAbove(item.strokes, of: item, glass: glass)
        }
        let active = try #require(overlay.itemViews.first)
        #expect(!active.accent.isHidden)
        // The minted count and state badges draw over the outline,
        // and the drop ring rides in the outline's clip.
        let sticky = try #require(active.stickyBadgeViews.first ?? nil)
        #expect(sticky.superview === active.aboveOutline)
        let count = try #require(active.badgeViews.first)
        #expect(count.superview === active.aboveOutline)
        #expect(active.springRing.superlayer === active.accentClip.layer)
        try expectHostLeavesRiders(
            active.strokes,
            glass: try #require(overlay.boxGlasses.first)
        )

        overlay.teardownBoxGlasses()

        expectHome(
            active,
            border: active.boxBorder,
            clip: active.accentClip,
            above: active.aboveOutline
        )
    }
}
