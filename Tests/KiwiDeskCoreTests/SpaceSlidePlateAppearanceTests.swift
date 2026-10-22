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
        under appearance: NSAppearance.Name
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
                pace: 1
            )
        )
        let play = try #require(overlay.play)
        // The panel must inherit `NSApp.appearance`, the pick; one
        // of its own would hide it from the plates.
        #expect(play.panel.appearance == nil)
        play.panel.appearance = NSAppearance(named: appearance)
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
