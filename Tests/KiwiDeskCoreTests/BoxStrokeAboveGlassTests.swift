import AppKit
import Testing

@testable import KiwiDeskCore

/// Under Boxed glass a box's border and outline stroke above its
/// glass, never inside it: the glass draws its key-window rim over
/// its content, which washed the outer point of either stroke white
/// (#2595, device 2026-10-25). Both bars render through their
/// overlays; a teardown hands the strokes back to the item.
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
                    count: 1,
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
        let overlay = SpaceBarOverlay()
        overlay.show(
            items: [1, 2].map { n in
                SpaceBarOverlay.Item(
                    space: SpaceID(String(n)),
                    spaceGlyph: .text(String(n), tinted: true),
                    apps: [],
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

    /// `strokes` sit in the host of `glass`, above it, the border
    /// beneath the outline, filling the box.
    private func expectAbove(
        _ strokes: [NSView],
        glass: NSView,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let host = try #require(
            GlassBox.host(of: glass),
            sourceLocation: sourceLocation
        )
        let order = host.subviews
        let below = try #require(
            order.firstIndex(of: glass),
            sourceLocation: sourceLocation
        )
        var last = below
        for stroke in strokes {
            let index = try #require(
                order.firstIndex(of: stroke),
                "a stroke left inside the glass",
                sourceLocation: sourceLocation
            )
            #expect(index > last, sourceLocation: sourceLocation)
            #expect(
                stroke.frame == host.bounds,
                sourceLocation: sourceLocation
            )
            last = index
        }
    }

    @Test("An App Bar box strokes above its glass")
    func appBarStrokesAbove() throws {
        try #require(Self.platformGlass)
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = appOverlay()
        #expect(overlay.boxGlasses.count == 2)
        for (item, glass) in zip(overlay.itemViews, overlay.boxGlasses) {
            #expect(GlassPlate.holds(glass, item))
            try expectAbove([item.boxBorder, item.accentClip], glass: glass)
        }
        // The outline is drawn, and takes no click from its item.
        let active = try #require(overlay.itemViews.first)
        #expect(!active.accent.isHidden)
        #expect(active.accentClip.hitTest(.zero) == nil)

        overlay.teardownBoxGlasses()

        #expect(active.boxBorder.superview === active)
        #expect(active.accentClip.superview === active)
        let order = active.subviews
        #expect(
            order.firstIndex(of: active.boxBorder) == 0,
            "the border is the bottom subview again"
        )
        #expect(
            try #require(order.firstIndex(of: active.accentClip))
                < (order.firstIndex(of: active.badge) ?? .max)
        )
    }

    @Test("A Space Bar box strokes above its glass")
    func spaceBarStrokesAbove() throws {
        try #require(Self.platformGlass)
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let overlay = spaceOverlay()
        #expect(overlay.boxGlasses.count == 2)
        for (item, glass) in zip(overlay.itemViews, overlay.boxGlasses) {
            #expect(GlassPlate.holds(glass, item))
            try expectAbove([item.boxBorder, item.accentClip], glass: glass)
        }
        let active = try #require(overlay.itemViews.first)
        #expect(!active.accent.isHidden)

        overlay.teardownBoxGlasses()

        #expect(active.boxBorder.superview === active)
        #expect(active.accentClip.superview === active)
        #expect(active.subviews.first === active.boxBorder)
    }
}
