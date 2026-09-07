import AppKit
import Testing

@testable import KiwiDeskCore

/// **The Liquid Glass cap has one channel, and no bypass beside
/// it** (#1297).
///
/// `GlassTint.apply` clamped the coloured backdrop to `maxAlpha`
/// while `GlassPlate.update` set `NSGlassEffectView.tintColor`
/// from the raw Fill — a clamp with an unbounded sibling, which
/// is not a clamp. Every bundled palette ships a bar fill at
/// `…B3`, so the uncapped channel ran at 0.70 on a default
/// install and the plate read as a slab.
///
/// These assert the CONSUMERS rather than the arithmetic: what a
/// backdrop's layer ends up carrying, and what the plate ends up
/// carrying. A test that only exercised the pure clamp would
/// have stayed green through the whole defect — the clamp was
/// always right; the second channel was the bug.
///
/// Every clause derives its expectation from
/// `GlassTint.maxAlpha` rather than restating today's number, so
/// a deliberate retune moves one constant and reds nothing
/// (tests.md ▸ #1021).
@Suite("Liquid Glass tint cap (#1297)")
@MainActor
struct GlassTintCapTests {
    private static let frame = CGRect(x: 0, y: 0, width: 80, height: 24)

    /// A host with a superview, which `apply` needs to insert into.
    private static func host() -> (glass: NSView, backdrop: NSView) {
        let parent = NSView(frame: frame)
        let glass = NSView(frame: frame)
        parent.addSubview(glass)
        return (glass, NSView(frame: frame))
    }

    /// The alpha a Fill actually lands on a backdrop's layer.
    private static func landed(_ hex: String) -> CGFloat? {
        let (glass, backdrop) = host()
        GlassTint.apply(
            backdrop,
            below: glass,
            frame: frame,
            cornerRadius: 4,
            hex: hex
        )
        guard !backdrop.isHidden else { return nil }
        return backdrop.layer?.backgroundColor?.alpha
    }

    /// Guard against a vacuous suite: below macOS 26 `rendered`
    /// answers nil for every Fill, so every clause here would
    /// pass having measured nothing.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// Both inputs are DERIVED from the cap. Spelling the shipped
    /// `…B3` (0.70) here read well — it is the palettes' own value
    /// and the one that shipped uncapped on the plate — but it is
    /// only "above the cap" while the cap is under 0.70: a
    /// `guard-prover` round set `maxAlpha` to 0.75 and this clause
    /// redded having caught no regression, which is the retune tax
    /// tests.md ▸ #1021 refuses. The shipped-palette fact lives in
    /// `GlassTint.maxAlpha`'s docstring instead.
    @Test("A Fill above the cap lands at the cap, not above it")
    func aboveTheCapIsClamped() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        try #require(
            GlassTint.maxAlpha < 1,
            "a cap of 1 clamps nothing, so there is no above"
        )
        let justOver = (GlassTint.maxAlpha + 1) / 2
        for alpha in [1.0, justOver] {
            let hex = String(
                format: "#14201C%02X",
                Int((alpha * 255).rounded())
            )
            let landed = try #require(Self.landed(hex))
            #expect(
                abs(landed - GlassTint.maxAlpha) < 0.01,
                "\(hex) landed \(landed), cap \(GlassTint.maxAlpha)"
            )
        }
    }

    @Test("A Fill under the cap renders exactly as picked")
    func underTheCapIsUntouched() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        // The clamp bends only what cannot render as glass; a user
        // below the ceiling gets the colour they chose. This is the
        // half a SCALE would have broken, and the consult refused a
        // scale on exactly this ground.
        let picked = GlassTint.maxAlpha / 2
        let hex = String(
            format: "#14201C%02X",
            Int((picked * 255).rounded())
        )
        let alpha = try #require(Self.landed(hex))
        #expect(abs(alpha - picked) < 0.01, "landed \(alpha)")
    }

    /// The require is not boilerplate here — it is the clause
    /// that stops this one passing for the wrong reason. Below
    /// macOS 26 the availability guard already answers nil, for
    /// the version rather than the alpha, so without it this
    /// clause is green having measured nothing (code review).
    @Test("A transparent Fill draws no backdrop at all")
    func transparentFillDrawsNothing() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        #expect(Self.landed("#14201C00") == nil)
    }

    /// **The channel #1297 was**, and it could not carry a colour
    /// — `docs/design-decisions.md` ▸ Liquid Glass has the
    /// measurement. A Fill driving it dimmed the plate by an
    /// amount the cap never saw.
    ///
    /// The plate takes no colour now, and this is what reds if one
    /// is handed back to it: the seam scan sees a *spelling*, and a
    /// re-added assignment could be spelled a way it does not
    /// match, but nothing can put a colour on the plate without
    /// this clause seeing it.
    @Test("The glass plate is handed no colour")
    func plateTakesNoColour() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        // Unreachable past the require above, which is what keeps
        // this clause from passing vacuously; the compiler still
        // needs the version check to name the type.
        guard #available(macOS 26, *) else { return }
        let plate = try #require(GlassPlate.make())
        GlassPlate.update(plate, frame: Self.frame, cornerRadius: 4)
        let glass = try #require(plate as? NSGlassEffectView)
        #expect(
            glass.tintColor == nil,
            "the plate carries \(String(describing: glass.tintColor))"
        )
    }
}
