import AppKit
import Testing

@testable import KiwiDeskCore

/// Whether a family moves along a `wght` axis or only between fixed
/// faces — the weight slider's enablement (#1859) — and the weight
/// such a family draws for a stored one.
@Suite("Bar font weight axis")
@MainActor
struct BarFontAxisTests {
    @Test("The system pair and a variable family have an axis")
    func axisFamilies() throws {
        #expect(BarFont.hasWeightAxis(KiwiShelf.systemFontFamily))
        #expect(BarFont.hasWeightAxis(KiwiShelf.systemMonospacedFontFamily))
        try #require(BarFont.isInstalled("STIX Two Text"))
        #expect(BarFont.hasWeightAxis("STIX Two Text"))
    }

    /// Skia carries a `wght` axis off the 100–900 scale, which
    /// `BarFont` never varies: it reads as fixed faces too.
    @Test("A family of fixed faces has none")
    func fixedFamilies() throws {
        for family in ["Menlo", "Apple Chancery", "Skia"] {
            try #require(BarFont.isInstalled(family), "\(family)")
            #expect(!BarFont.hasWeightAxis(family), "\(family)")
        }
    }

    /// A missing family draws System, which can.
    @Test("A missing family reads as System's axis")
    func missingFamily() {
        #expect(BarFont.hasWeightAxis("KiwiDesk No Such Family"))
    }

    @Test("A fixed family draws its nearest face's weight")
    func drawnWeight() throws {
        try #require(BarFont.isInstalled("Apple Chancery"))
        let drawn = BarFont.drawnWeight(
            family: "Apple Chancery",
            weight: 700
        )
        #expect(drawn != 700)
        #expect(
            BarFont.drawnWeight(family: "Apple Chancery", weight: drawn)
                == drawn
        )
        #expect(
            BarFont.drawnWeight(
                family: KiwiShelf.systemFontFamily,
                weight: 540
            ) == 540
        )
    }
}
