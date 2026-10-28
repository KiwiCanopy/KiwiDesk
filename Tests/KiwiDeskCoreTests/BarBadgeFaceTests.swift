import AppKit
import Testing

@testable import KiwiDeskCore

/// A badge's rim parts its disc from the glass, so the shelf's Fill
/// picks its polarity, never the disc (#2722): dark glass takes a
/// white rim, light glass a black one, and a shelf with no Fill
/// follows the appearance its glass follows.
@Suite("Bar badge face (#2722)")
struct BarBadgeFaceTests {
    private func shelf(fill: String) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.fillColor = fill
        return shelf
    }

    private func white(_ rim: NSColor) -> Bool {
        (rim.usingColorSpace(.sRGB)?.redComponent ?? 0) > 0.5
    }

    @Test("The shelf's Fill picks the rim, not the disc or the pick")
    func shelfPicksTheRim() {
        for dark in [false, true] {
            let onDark = BarBadgeFace.rim(
                on: shelf(fill: "#1A1A2EA5"),
                dark: dark
            )
            let onLight = BarBadgeFace.rim(
                on: shelf(fill: "#F2F2F7B3"),
                dark: dark
            )
            #expect(white(onDark))
            #expect(!white(onLight))
        }
    }

    @Test("A shelf with no Fill follows the appearance")
    func noFillFollowsTheAppearance() {
        #expect(white(BarBadgeFace.rim(on: shelf(fill: ""), dark: true)))
        #expect(!white(BarBadgeFace.rim(on: shelf(fill: ""), dark: false)))
    }

    /// A dimmed badge dims its rim with its mark.
    @Test("The rim dims with the badge's tier")
    func rimDimsWithTheTier() {
        for fill in ["#1A1A2EA5", "#F2F2F7B3"] {
            let glass = shelf(fill: fill)
            let full = BarBadgeFace.rim(on: glass, dark: true)
            let dim = BarBadgeFace.rim(on: glass, dark: true, tier: 0.4)
            #expect(
                abs(dim.alphaComponent - full.alphaComponent * 0.4) < 0.001,
                "\(fill)"
            )
        }
    }
}
