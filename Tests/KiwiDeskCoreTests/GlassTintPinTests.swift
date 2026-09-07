import AppKit
import Testing

@testable import KiwiDeskCore

/// **The glass variant is pinned from the Fill, and lifted by
/// it** (#1308).
///
/// macOS decides a Liquid Glass view's light or dark variant from
/// the backdrop that view samples, and the verdict sticks — two
/// bars sharing a Fill diverged, and either could be the dark one
/// (the measurement is in `docs/design-decisions.md` ▸ Liquid
/// Glass). `GlassTint.apply` now pins the variant from the Fill,
/// so both bars follow one rule.
///
/// These assert the CONSUMER — what the glass view's `appearance`
/// ends up being after `apply` — rather than the pure decision,
/// for `GlassTintCapTests`' reason: the bars keep one glass view
/// across Fill changes, so a pin that is set but never lifted is
/// the defect one step over.
@Suite("Liquid Glass variant pin (#1308)")
@MainActor
struct GlassTintPinTests {
    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// A host with a superview, which `apply` needs to insert into.
    private static func host() -> (glass: NSView, backdrop: NSView) {
        let parent = NSView(frame: frame)
        let glass = NSView(frame: frame)
        parent.addSubview(glass)
        return (glass, NSView(frame: frame))
    }

    /// Applies `hex` to `glass` and reads the pin it left.
    private static func pin(
        _ hex: String,
        on glass: NSView,
        backdrop: NSView
    ) -> NSAppearance.Name? {
        GlassTint.apply(
            backdrop,
            below: glass,
            frame: frame,
            cornerRadius: 4,
            hex: hex
        )
        return glass.appearance?.name
    }

    /// Below macOS 26 the pin answers nil for every Fill, so every
    /// clause here would pass having measured nothing.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    @Test("A dark Fill pins the dark variant")
    func darkFillPinsDark() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (glass, backdrop) = Self.host()
        #expect(
            Self.pin("#000000B3", on: glass, backdrop: backdrop)
                == .darkAqua
        )
    }

    @Test("A light Fill leaves the OS's scheme")
    func lightFillLeavesTheOS() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (glass, backdrop) = Self.host()
        #expect(
            Self.pin("#FFFFFFB3", on: glass, backdrop: backdrop) == nil
        )
    }

    /// No tint means the glass samples the bare desktop, which is
    /// the OS's own case; nothing here knows better than it.
    @Test("A transparent Fill leaves the OS's scheme")
    func transparentFillLeavesTheOS() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (glass, backdrop) = Self.host()
        #expect(
            Self.pin("#00000000", on: glass, backdrop: backdrop) == nil
        )
    }

    /// The consumer clause. A bar keeps its glass view across
    /// `set_fill_color`, so a pin left behind by the previous Fill
    /// is exactly the sticky verdict this replaces.
    @Test("A light Fill after a dark one lifts the pin")
    func lightFillLiftsThePin() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let (glass, backdrop) = Self.host()
        try #require(
            Self.pin("#000000B3", on: glass, backdrop: backdrop)
                == .darkAqua
        )
        #expect(
            Self.pin("#FFFFFFB3", on: glass, backdrop: backdrop) == nil
        )
    }

    /// The pin and the ink read one threshold. Expectations are
    /// DERIVED from `wantsLightInk` rather than restated, so a
    /// retune of the threshold moves one number and reds nothing
    /// (tests.md ▸ #1021); the two hues straddle today's value so
    /// the clause exercises both branches.
    @Test("The pin follows the ink threshold, not a second one")
    func pinFollowsTheInkThreshold() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let hues = ["#4E9F3DB3", "#EAF3EEB3"]
        let inks = hues.map { NSColor(kiwiHex: $0).wantsLightInk }
        try #require(
            Set(inks).count == 2,
            "both hues fall on one side of the threshold: \(hues)"
        )
        for (hex, wantsLightInk) in zip(hues, inks) {
            let (glass, backdrop) = Self.host()
            let pinned =
                Self.pin(hex, on: glass, backdrop: backdrop)
                == .darkAqua
            #expect(
                pinned == wantsLightInk,
                "\(hex): pinned \(pinned), wants light ink \(wantsLightInk)"
            )
        }
    }
}
