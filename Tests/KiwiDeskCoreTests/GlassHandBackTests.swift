import AppKit
import Testing

@testable import KiwiDeskCore

/// A view a glass hosted comes back frame-laid (#1730): hosting
/// turns `translatesAutoresizingMaskIntoConstraints` off, and a
/// view handed back with it still off is placed by the next layout
/// pass at its intrinsic size in the corner — the clipped row the
/// owner met after switching the shelf from Boxed to Plain.
@Suite("Glass hands its content back frame-laid (#1730)")
@MainActor
struct GlassHandBackTests {
    private static var platformGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    @Test("release returns the content in frame layout")
    func releaseRestoresFrameLayout() throws {
        try #require(Self.platformGlass)
        let glass = try #require(GlassPlate.make())
        let item = NSView()
        GlassPlate.setContent(glass, item)
        // The premise: hosting takes the view out of frame layout.
        #expect(!item.translatesAutoresizingMaskIntoConstraints)
        #expect(GlassPlate.release(glass) === item)
        #expect(item.translatesAutoresizingMaskIntoConstraints)
        #expect(!GlassPlate.holds(glass, item))
        #expect(GlassPlate.release(glass) == nil)
    }

    /// The device path: a boxed glass App Bar hosts each item in a
    /// glass; switched to Plain, every item is back in the item
    /// container and frame-laid.
    @Test("Boxed to Plain returns every item frame-laid")
    func boxedToPlainReturnsItems() throws {
        try #require(Self.platformGlass)
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { false }
        let manager = AppBarManager()
        for boxed in [true, false] {
            var style = AppBarLook()
            style.liquidGlass = true
            style.backgroundStyle = boxed ? .boxed : .plain
            manager.sync([
                AppBarManager.Bar(
                    display: barTitleDisplay,
                    space: SpaceID("1"),
                    items: [
                        appBarItem(1, text: "One"),
                        appBarItem(2, text: "Two"),
                    ],
                    activeIndex: 0,
                    strip: barTitleStrip,
                    style: style,
                    capAxis: barTitleStrip.width
                )
            ])
        }
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.boxGlasses.isEmpty)
        #expect(overlay.itemViews.count == 2)
        for item in overlay.itemViews {
            #expect(item.superview === overlay.itemContainer)
            #expect(item.translatesAutoresizingMaskIntoConstraints)
        }
    }
}
