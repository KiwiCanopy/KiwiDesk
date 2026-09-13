import AppKit
import Testing

@testable import KiwiDeskCore

/// Reduce transparency stands Liquid Glass down at render time
/// (#1374): `LiquidGlassGate.rendered` at each bar's one render
/// read, `GlassTint` refusing a colour as the net beneath it, and
/// the observer that re-draws on the flip. The stored
/// `liquid_glass` value is never moved.
///
/// The OS read is overridden INSIDE each test body, synchronously
/// on the main actor with a `defer` restore, so no other suite can
/// observe the flipped value; every glass fixture pins it off in
/// `init` (`ReduceTransparencySeamTests` holds that every one
/// does).
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
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { reduced }
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

    /// Glass off and BOTH fills opaque — the hover fill replaces
    /// the box fill under the pointer, so left alone it would be
    /// the one translucent box on the bar — and nothing else.
    @Test("the rendered style drops glass and alpha, nothing else")
    func renderedStyleDropsGlassOnly() {
        var app = AppBarFixtures.everyGlobalField()
        app.liquidGlass = true
        app.fillColor = "#020202B3"
        app.hoverFillColor = "#06060680"
        var space = SpaceBarStyle()
        space.liquidGlass = true
        space.backgroundStyle = .boxed
        space.fillColor = "#030303B3"
        space.hoverFillColor = "#07070780"

        reducing(true) {
            var expectedApp = app
            expectedApp.liquidGlass = false
            expectedApp.fillColor = "#020202"
            expectedApp.hoverFillColor = "#060606"
            #expect(LiquidGlassGate.rendered(app) == expectedApp)
            var expectedSpace = space
            expectedSpace.liquidGlass = false
            expectedSpace.fillColor = "#030303"
            expectedSpace.hoverFillColor = "#070707"
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
    /// while transparency is reduced — the solid shape — in BOTH
    /// directions: the device flip tears hosted glass down, and
    /// lifts it back.
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
        for reduced in [false, true, false] {
            try reducing(reduced) {
                manager.sync([bar])
                let overlay = try #require(
                    manager.overlayForTesting(barTitleDisplay)
                )
                #expect(
                    overlay.boxGlasses.count == (reduced ? 0 : 1),
                    Comment(rawValue: "reduced: \(reduced)")
                )
                #expect(overlay.glassPlate?.isHidden ?? true)
                #expect(
                    overlay.itemViews.first?.style.hasBox == reduced,
                    Comment(rawValue: "reduced: \(reduced)")
                )
            }
        }
    }

    /// The Space Bar's plain glass run stands down the same way.
    @Test("a plain glass Space Bar draws its solid plate")
    func spaceBarDrawsSolidPlate() throws {
        try #require(Self.platformGlass)
        let bar = paintedSpaceBar(front: nil, spaces: 2, glass: true)
        let manager = SpaceBarManager()
        for reduced in [false, true, false] {
            try reducing(reduced) {
                manager.sync([bar])
                let overlay = try #require(
                    manager.overlayForTesting(barTitleDisplay)
                )
                #expect(
                    (overlay.glassPlate?.isHidden ?? true) == reduced,
                    Comment(rawValue: "reduced: \(reduced)")
                )
                #expect(
                    (overlay.plainPlate?.isHidden ?? true) == !reduced,
                    Comment(rawValue: "reduced: \(reduced)")
                )
            }
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

    /// The live half rests on the observer hearing the right
    /// notification and delivering on the main actor; a wrong name
    /// leaves both bars on stale glass until an unrelated retile.
    /// Posted on the workspace centre, process-local — no machine
    /// setting is touched.
    @Test("the observer hears the accessibility options change")
    func observerHearsTheFlip() {
        var fired = 0
        let token = LiquidGlassGate.observe { fired += 1 }
        defer {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace
                .accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared
        )
        #expect(fired == 1)
        NotificationCenter.default.post(
            name: NSWorkspace
                .accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        #expect(fired == 1, "the default centre is not the channel")
    }

    /// The wiring is idempotent and symmetric: wiring twice holds
    /// ONE observer, and `stop()` retires it — a revoke runs both
    /// on one core. The handler is driven directly, the way
    /// `ownKeyWindowDidChange` is.
    @Test("the wiring holds one observer and stop() retires it")
    func wiringIsSymmetric() throws {
        try #require(Self.platformGlass)
        let core = makeTestCore()
        #expect(core.appBars.transparencyObserver == nil)
        core.wireReduceTransparency()
        let first = try #require(core.appBars.transparencyObserver)
        core.wireReduceTransparency()
        let second = try #require(core.appBars.transparencyObserver)
        #expect(first !== second, "re-wiring kept the first token")
        core.reduceTransparencyDidChange()
        core.retireReduceTransparency()
        #expect(core.appBars.transparencyObserver == nil)
    }
}
