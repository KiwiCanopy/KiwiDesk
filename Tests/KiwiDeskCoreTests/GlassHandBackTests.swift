import AppKit
import Testing

@testable import KiwiDeskCore

/// A view a glass hosted comes back frame-laid and where the layout
/// puts it (#1730). Hosting turns
/// `translatesAutoresizingMaskIntoConstraints` off, and a bar that
/// handed its items back with it off — or after its frame pass had
/// already skipped them — drew them in the shelf's corner once the
/// style went from Boxed to Plain.
@Suite("Glass hands its content back frame-laid (#1730)")
@MainActor
struct GlassHandBackTests {
    private static var platformGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Glass off in the OS read, restored after the body.
    private func withGlass<T>(_ body: () throws -> T) rethrows -> T {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { false }
        return try body()
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

    @Test("new content releases the view it displaces")
    func swapReleasesTheOld() throws {
        try #require(Self.platformGlass)
        let glass = try #require(GlassPlate.make())
        let first = NSView()
        GlassPlate.setContent(glass, first)
        GlassPlate.setContent(glass, NSView())
        #expect(first.translatesAutoresizingMaskIntoConstraints)
    }

    private func appBar(boxed: Bool) -> AppBarManager.Bar {
        var style = AppBarLook()
        style.liquidGlass = true
        style.backgroundStyle = boxed ? .boxed : .plain
        return AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: [appBarItem(1, text: "One"), appBarItem(2, text: "Two")],
            activeIndex: 0,
            strip: barTitleStrip,
            style: style,
            capAxis: barTitleStrip.width
        )
    }

    /// Boxed → Plain lands every App Bar item where a bar drawn
    /// Plain from the start puts it, in the same render.
    @Test("App Bar: Boxed to Plain returns every item in place")
    func appBarBoxedToPlain() throws {
        try #require(Self.platformGlass)
        try withGlass {
            let switched = AppBarManager()
            switched.sync([appBar(boxed: true)])
            // The display cycle: glass lays its content out.
            try #require(switched.overlayForTesting(barTitleDisplay))
                .itemContainer.layoutSubtreeIfNeeded()
            switched.sync([appBar(boxed: false)])
            let fresh = AppBarManager()
            fresh.sync([appBar(boxed: false)])
            let after = try #require(
                switched.overlayForTesting(barTitleDisplay)
            )
            let plain = try #require(
                fresh.overlayForTesting(barTitleDisplay)
            )
            #expect(after.boxGlasses.isEmpty)
            #expect(after.itemViews.count == 2)
            for (item, expected) in zip(after.itemViews, plain.itemViews) {
                #expect(item.superview === after.itemRun)
                #expect(item.translatesAutoresizingMaskIntoConstraints)
                #expect(item.frame == expected.frame)
            }
        }
    }

    /// The device bug itself: the Space Bar's items after Boxed →
    /// Plain.
    @Test("Space Bar: Boxed to Plain returns every item in place")
    func spaceBarBoxedToPlain() throws {
        try #require(Self.platformGlass)
        try withGlass {
            let switched = SpaceBarManager()
            switched.sync([collapsedBar(.apps, boxedGlass: true)])
            // The display cycle: glass lays its content out.
            try #require(switched.overlayForTesting(barTitleDisplay))
                .itemContainer.layoutSubtreeIfNeeded()
            switched.sync([collapsedBar(.apps, boxedGlass: false)])
            let fresh = SpaceBarManager()
            fresh.sync([collapsedBar(.apps, boxedGlass: false)])
            let after = try #require(
                switched.overlayForTesting(barTitleDisplay)
            )
            let plain = try #require(
                fresh.overlayForTesting(barTitleDisplay)
            )
            #expect(after.boxGlasses.isEmpty)
            #expect(!after.itemViews.isEmpty)
            for (item, expected) in zip(after.itemViews, plain.itemViews) {
                #expect(item.superview === after.itemContainer)
                #expect(item.translatesAutoresizingMaskIntoConstraints)
                #expect(item.frame == expected.frame)
            }
        }
    }

    /// The sticky mark's glyphs follow the pill morph by their
    /// autoresizing mask, which works only in frame layout.
    @Test("the sticky mark's glass hands its glyphs back")
    func stickyMarkHandsBack() throws {
        try #require(Self.platformGlass)
        let plate = StickyMarkPlate()
        plate.setGlass(true)
        plate.setGlass(false)
        #expect(plate.content.superview === plate)
        #expect(plate.content.translatesAutoresizingMaskIntoConstraints)
    }
}
