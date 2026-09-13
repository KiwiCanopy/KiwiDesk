import AppKit
import Testing

@testable import KiwiDeskCore

/// Reduce transparency stands Liquid Glass down at render time
/// (#1374). `NSGlassEffectView` ignores the setting — measured
/// 2026-09-13, live and at creation — so the stand-down is ours:
/// `LiquidGlassGate.rendered` at each bar's one render read, and
/// `GlassTint` refusing a colour as the net beneath it. The stored
/// `liquid_glass` value is never moved.
///
/// The OS read is injected and flipped INSIDE each test body,
/// synchronously on the main actor, so no other suite can observe
/// the flipped value; every glass fixture pins it off in `init`.
@Suite("Reduce transparency stands glass down (#1374)")
@MainActor
struct ReduceTransparencyTests {
    /// Below macOS 26 nothing hosts glass with the setting off
    /// either, so the hosting clauses would pass having measured
    /// nothing; the style clauses hold everywhere.
    private static var platformGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private func reducing<T>(
        _ reduced: Bool,
        _ body: () throws -> T
    ) rethrows -> T {
        let before = LiquidGlassGate.reducesTransparency
        defer { LiquidGlassGate.reducesTransparency = before }
        LiquidGlassGate.reducesTransparency = { reduced }
        return try body()
    }

    /// The setting asks for OPAQUE backgrounds: a Fill keeps its
    /// hue and loses its alpha, a transparent one stays no plate.
    @Test("the Fill renders opaque, a transparent one stays absent")
    func fillRendersOpaque() {
        #expect(LiquidGlassGate.opaque("#14201CB3") == "#14201C")
        #expect(LiquidGlassGate.opaque("#14201C") == "#14201C")
        #expect(LiquidGlassGate.opaque("14201C40") == "#14201C")
        #expect(LiquidGlassGate.opaque("#00000000") == "#00000000")
        #expect(LiquidGlassGate.opaque("not a colour") == "not a colour")
    }

    @Test("the rendered style drops glass and alpha, nothing else")
    func renderedStyleDropsGlassOnly() {
        var app = AppBarFixtures.everyGlobalField()
        app.liquidGlass = true
        app.fillColor = "#020202B3"
        var space = SpaceBarStyle()
        space.liquidGlass = true
        space.backgroundStyle = .boxed

        reducing(true) {
            var expectedApp = app
            expectedApp.liquidGlass = false
            expectedApp.fillColor = "#020202"
            #expect(LiquidGlassGate.rendered(app) == expectedApp)
            var expectedSpace = space
            expectedSpace.liquidGlass = false
            expectedSpace.fillColor = LiquidGlassGate.opaque(
                space.fillColor
            )
            #expect(LiquidGlassGate.rendered(space) == expectedSpace)
            #expect(!LiquidGlassGate.drawsGlass)
        }
        reducing(false) {
            #expect(LiquidGlassGate.rendered(app) == app)
            #expect(LiquidGlassGate.rendered(space) == space)
            #expect(
                LiquidGlassGate.drawsGlass
                    == AppBarStyle.glassAvailable
            )
        }
        // The stored value the copy was made from did not move.
        #expect(app.liquidGlass)
        #expect(space.liquidGlass)
    }

    /// A boxed glass App Bar hosts no glass and draws its box
    /// while transparency is reduced — the solid shape — and
    /// hosts glass again the moment it is not.
    @Test("a boxed glass App Bar draws its solid box")
    func appBarDrawsSolidBox() throws {
        try #require(Self.platformGlass)
        var style = AppBarStyle()
        style.backgroundStyle = .boxed
        style.liquidGlass = true
        let bar = AppBarManager.Bar(
            display: barTitleDisplay,
            space: SpaceID("1"),
            items: [appBarItem(1, text: "One")],
            activeIndex: 0,
            strip: barTitleStrip,
            style: style
        )
        let manager = AppBarManager()
        try reducing(true) {
            manager.sync([bar])
            let overlay = try #require(
                manager.overlayForTesting(barTitleDisplay)
            )
            #expect(overlay.boxGlasses.isEmpty)
            #expect(overlay.glassPlate?.isHidden ?? true)
        }
        try reducing(false) {
            manager.sync([bar])
            let overlay = try #require(
                manager.overlayForTesting(barTitleDisplay)
            )
            #expect(overlay.boxGlasses.count == 1)
        }
    }

    /// The Space Bar's plain glass run stands down the same way.
    @Test("a plain glass Space Bar draws its solid plate")
    func spaceBarDrawsSolidPlate() throws {
        try #require(Self.platformGlass)
        let bar = paintedSpaceBar(front: nil, spaces: 2, glass: true)
        let manager = SpaceBarManager()
        try reducing(true) {
            manager.sync([bar])
            let overlay = try #require(
                manager.overlayForTesting(barTitleDisplay)
            )
            #expect(overlay.glassPlate?.isHidden ?? true)
            #expect(overlay.plainPlate?.isHidden == false)
        }
        try reducing(false) {
            manager.sync([bar])
            let overlay = try #require(
                manager.overlayForTesting(barTitleDisplay)
            )
            #expect(overlay.glassPlate?.isHidden == false)
        }
    }

    /// The net: a Fill reaches no colour on glass while
    /// transparency is reduced, whatever a call site hands in.
    @Test("GlassTint paints nothing while transparency is reduced")
    func tintStandsDown() throws {
        try #require(Self.platformGlass)
        let glass = NSView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        let parent = NSView(frame: glass.frame)
        parent.addSubview(glass)
        let backdrop = NSView()
        reducing(true) {
            GlassTint.apply(
                backdrop,
                below: glass,
                frame: glass.frame,
                cornerRadius: 4,
                hex: "#000000B3"
            )
            #expect(backdrop.isHidden)
            #expect(glass.appearance == nil)
        }
        reducing(false) {
            GlassTint.apply(
                backdrop,
                below: glass,
                frame: glass.frame,
                cornerRadius: 4,
                hex: "#000000B3"
            )
            #expect(!backdrop.isHidden)
        }
    }
}
