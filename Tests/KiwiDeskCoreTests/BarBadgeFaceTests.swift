import AppKit
import Testing

@testable import KiwiDeskCore

/// A badge's rim parts its disc from the glass, so the shelf's Fill
/// picks its polarity, never the disc (#2722): a light disc on dark
/// glass takes a white rim, a dark disc on light glass a black one.
@Suite("Bar badge face (#2722)")
struct BarBadgeFaceTests {
    private func white(_ rim: NSColor) -> Bool {
        (rim.usingColorSpace(.sRGB)?.redComponent ?? 0) > 0.5
    }

    @Test("The shelf's Fill picks the rim, not the disc")
    func shelfPicksTheRim() {
        let lavender = NSColor(kiwiHex: "#B38ED9")
        let grey = NSColor(kiwiHex: "#636366")
        #expect(white(BarBadgeFace.rim(on: lavender, shelfFill: "#1A1A2EA5")))
        #expect(white(BarBadgeFace.rim(on: grey, shelfFill: "#000000B3")))
        #expect(!white(BarBadgeFace.rim(on: grey, shelfFill: "#F2F2F7B3")))
        #expect(
            !white(BarBadgeFace.rim(on: lavender, shelfFill: "#FFFFFFB3"))
        )
    }

    @Test("A shelf with no Fill takes the disc's polarity")
    func noFillTakesTheDisc() {
        let lavender = NSColor(kiwiHex: "#B38ED9")
        #expect(!white(BarBadgeFace.rim(on: lavender, shelfFill: "")))
        let navy = NSColor(kiwiHex: "#1A1A2E")
        #expect(white(BarBadgeFace.rim(on: navy, shelfFill: "")))
    }
}
