import AppKit
import Testing

@testable import KiwiDeskCore

/// **The slide's glass plates follow the Appearance pick**
/// (#2539). Unpinned, a glass view takes its variant from the
/// backdrop it samples (#1308) — here the windows being switched —
/// rather than from the pick KiwiHub follows. Each plate and
/// pile container is pinned through `GlassTint.followPick` from
/// the panel's effective appearance, the pick it carries.
///
/// Asserts the CONSUMER — the glass views a real page builds —
/// so a plate path that stops calling the door reds here.
@Suite("Plate slide glass follows the pick (#2539)", .serialized)
@MainActor
struct SpaceSlidePlateAppearanceTests {
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1000,
        height: 800
    )

    /// The glass views of the pages a play built, after its
    /// panel took `appearance`.
    private func plateGlass(
        under appearance: NSAppearance.Name,
        tint: GlassFill? = nil,
        panel: ((NSPanel) -> Void)? = nil
    ) throws -> [NSView] {
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.icon = { _ in nil }
        defer { overlay.end() }
        _ = overlay.press(
            SpaceSlideOverlay.Press(
                display: DisplayID(1),
                screen: Self.screen,
                axis: .horizontal,
                direction: 1,
                outgoing: [],
                holes: [],
                space: SpaceID("2"),
                glass: true,
                tint: tint,
                pace: 1
            )
        )
        let play = try #require(overlay.play)
        // The panel must inherit `NSApp.appearance`, the pick; one
        // of its own would hide it from the plates.
        #expect(play.panel.appearance == nil)
        play.panel.appearance = NSAppearance(named: appearance)
        panel?(play.panel)
        overlay.run(
            incoming: [
                SpaceSlidePlan.Plate(
                    id: WindowID(1),
                    frame: CGRect(x: 100, y: 100, width: 400, height: 300),
                    iconPid: nil,
                    pile: 0
                )
            ],
            holes: []
        )
        // A glass's content may also be its subview: count once.
        var seen: Set<ObjectIdentifier> = []
        return Self.glassViews(in: play.strip).filter {
            seen.insert(ObjectIdentifier($0)).inserted
        }
    }

    private static func glassViews(in view: NSView) -> [NSView] {
        guard #available(macOS 26, *) else { return [] }
        var found: [NSView] = []
        if view is NSGlassEffectView || view is NSGlassEffectContainerView {
            found.append(view)
        }
        for sub in view.subviews { found += glassViews(in: sub) }
        if let glass = view as? NSGlassEffectView,
            let content = glass.contentView
        {
            found += glassViews(in: content)
        }
        if let box = view as? NSGlassEffectContainerView,
            let content = box.contentView
        {
            found += glassViews(in: content)
        }
        return found
    }

    /// Below macOS 26 no plate is glass, so every clause here
    /// would pass having measured nothing.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    @Test("a dark pick pins every plate and container dark")
    func darkPickPinsDark() throws {
        guard Self.drawsGlass else { return }
        let glass = try plateGlass(under: .darkAqua)
        // One container and one plate, or the clause reads nothing.
        #expect(glass.count == 2)
        for view in glass {
            #expect(view.appearance?.name == .darkAqua)
        }
    }

    @Test("a light pick pins nothing")
    func lightPickPinsNothing() throws {
        guard Self.drawsGlass else { return }
        let glass = try plateGlass(under: .aqua)
        #expect(glass.count == 2)
        for view in glass {
            #expect(view.appearance == nil)
        }
    }

    /// "Tint KiwiHub and plates" on (#2569): the plate draws
    /// `.clear` glass carrying the Fill, and its panel wears the
    /// key-window rim; off, today's frosted plate and no rim.
    @Test(
        "a tinted plate is clear glass with the Fill",
        arguments: [true, false]
    )
    func tintedPlateWearsTheFill(tinted: Bool) throws {
        guard Self.drawsGlass, #available(macOS 26, *) else { return }
        var wears: Bool?
        let glass = try plateGlass(
            under: .aqua,
            tint: tinted ? GlassFill(hex: "#14201CB3") : nil,
            panel: { wears = ($0 as? ActiveGlassPanel)?.wearsActiveLook }
        )
        #expect(wears == tinted, "the panel's rim follows the toggle")
        let plate = try #require(
            glass.compactMap { $0 as? NSGlassEffectView }.first
        )
        #expect(plate.style == (tinted ? .clear : .regular))
        let backdrop = plate.contentView as? GlassBackdrop
        #expect((backdrop?.gradient?.colors != nil) == tinted)
    }

    /// AppKit pins only dark (#2569): a light Fill's plate follows
    /// the pick, a dark Fill's stays dark under a light pick.
    @Test("a tinted plate pins dark only for a dark Fill")
    func tintedPlateFollowsThePickWhenLight() throws {
        guard Self.drawsGlass, #available(macOS 26, *) else { return }
        func plate(
            _ pick: NSAppearance.Name,
            _ hex: String
        ) throws -> NSView {
            let glass = try plateGlass(under: pick, tint: GlassFill(hex: hex))
            return try #require(
                glass.compactMap { $0 as? NSGlassEffectView }.first
            )
        }
        let light = "#F2F2F2B3"
        #expect(try plate(.darkAqua, light).appearance?.name == .darkAqua)
        #expect(try plate(.aqua, light).appearance == nil)
        #expect(try plate(.aqua, "#14201CB3").appearance?.name == .darkAqua)
    }

    /// The door LIFTS a pin a dark pick left, not only declines to
    /// set one: a fresh plate cannot tell the two apart.
    @Test("a light pick lifts a dark pin")
    func lightPickLiftsThePin() throws {
        let view = NSView()
        let dark = try #require(NSAppearance(named: .darkAqua))
        let light = try #require(NSAppearance(named: .aqua))
        GlassTint.followPick(view, host: dark)
        #expect(view.appearance?.name == .darkAqua)
        GlassTint.followPick(view, host: light)
        #expect(view.appearance == nil)
    }
}
