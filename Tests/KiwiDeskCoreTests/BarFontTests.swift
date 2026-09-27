import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.font_family` / `font_weight` (#1681): stored as
/// asked, resolved at render time by `BarFont`.
@Suite("KiwiShelf font family and weight")
@MainActor
struct BarFontTests {
    private static func width(_ font: NSFont) -> CGFloat {
        ("Spaces 1234" as NSString).size(withAttributes: [.font: font])
            .width
    }

    /// The default is the look that shipped before the setting.
    @Test("The default draws today's system font")
    func defaultIsTodaysLook() {
        let shelf = KiwiShelf()
        #expect(shelf.fontFamily == KiwiShelf.systemFontFamily)
        #expect(shelf.fontWeight == 400)
        #expect(shelf.textFont(ofSize: 13) == .systemFont(ofSize: 13))
        #expect(shelf.fontRendering == .exact)
        // Counts keep today's proportional system digits too.
        #expect(
            shelf.badgeFont(ofSize: 12, emphasis: .bold)
                == .systemFont(ofSize: 12, weight: .bold)
        )
        #expect(
            shelf.badgeFont(ofSize: 12, emphasis: .semibold)
                == .systemFont(ofSize: 12, weight: .semibold)
        )
    }

    @Test(
        "Decode rounds and clamps the weight",
        arguments: [(50.0, 100), (1200.0, 900), (540.4, 540)]
    )
    func decodeClamps(stored: Double, weight: Int) throws {
        let json = #"{"font_weight": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.fontWeight == weight)
    }

    @Test(
        "The weight setter takes a number or a name",
        arguments: [
            (JSONValue.number(540), 540), (.number(2000), 900),
            (.string("Semibold"), 600), (.string("semi-bold"), 600),
            (.string("LIGHT"), 300), (.string("ultralight"), 100),
        ]
    )
    func weightSetter(arg: JSONValue, weight: Int) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "font_weight",
            args: [arg]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.fontWeight == weight)
    }

    @Test("A weight neither number nor name is refused with the names")
    func weightRefusal() {
        let parsed = KiwiShelfCommandSetting.parse(
            field: "font_weight",
            args: [.string("chunky")]
        )
        guard case .failure(let error) = parsed else {
            Issue.record("accepted an unknown weight")
            return
        }
        #expect(error.message.contains(BarFontWeight.expectedList))
    }

    @Test("An empty family is refused")
    func emptyFamilyRefused() {
        let parsed = KiwiShelfCommandSetting.parse(
            field: "font_family",
            args: [.string("  ")]
        )
        #expect((try? parsed.get()) == nil)
    }

    /// The ruling's measurement: an in-between weight on a
    /// variable family draws its own width, never the named
    /// neighbour's.
    @Test("A variable family draws the exact weight")
    func variableFamilyIsExact() {
        let widths = [500, 520, 540, 560, 600].map {
            Self.width(
                BarFont.font(
                    family: KiwiShelf.systemFontFamily,
                    weight: $0,
                    size: 13
                )
            )
        }
        #expect(Set(widths).count == widths.count, "\(widths)")
        #expect(widths == widths.sorted(), "\(widths)")
        #expect(
            BarFont.rendering(family: KiwiShelf.systemFontFamily, weight: 540)
                == .exact
        )
    }

    /// Menlo has no `wght` axis and two upright faces: 540 sits
    /// nearer its Regular, 650 nearer its Bold.
    @Test("A family without an axis draws its nearest face")
    func nearestFace() throws {
        try #require(BarFont.isInstalled("Menlo"))
        let near400 = BarFont.font(family: "Menlo", weight: 540, size: 13)
        let near700 = BarFont.font(family: "Menlo", weight: 650, size: 13)
        #expect(near400.fontName == "Menlo-Regular")
        #expect(near700.fontName == "Menlo-Bold")
        #expect(
            BarFont.rendering(family: "Menlo", weight: 540)
                == .nearestFace(weight: 400)
        )
        #expect(BarFont.rendering(family: "Menlo", weight: 700) == .exact)
    }

    @Test("A family's chips are the weights it has")
    func offeredWeights() throws {
        try #require(BarFont.isInstalled("Menlo"))
        let offered = BarFontWeight.chips.filter {
            BarFont.offers(weight: $0.value, family: "Menlo")
        }
        #expect(offered == [.regular, .bold])
        #expect(
            BarFontWeight.chips.allSatisfy {
                BarFont.offers(
                    weight: $0.value,
                    family: KiwiShelf.systemFontFamily
                )
            }
        )
    }

    @Test("A missing family draws System and says so")
    func missingFamily() {
        let family = "KiwiDesk No Such Family"
        #expect(!BarFont.isInstalled(family))
        #expect(BarFont.rendering(family: family, weight: 400) == .missing)
        #expect(
            BarFont.font(family: family, weight: 400, size: 13)
                == .systemFont(ofSize: 13)
        )
        #expect(!BarFont.offers(weight: 400, family: family))
    }

    /// Resolved at render time: a family switch never rewrites
    /// the stored weight, so A → B → A keeps the choice.
    @Test("A family round trip keeps the weight")
    func familyRoundTripKeepsWeight() throws {
        var shelf = KiwiShelf()
        KiwiShelfCommandSetting.fontWeight(540).apply(to: &shelf)
        for family in ["Menlo", KiwiShelf.systemFontFamily] {
            KiwiShelfCommandSetting.fontFamily(family).apply(to: &shelf)
            #expect(shelf.fontWeight == 540)
        }
    }

    /// A chosen family's count keeps its width as it changes;
    /// Apple Chancery's own figures are proportional and it has
    /// tabular ones (most proportional families shipped with macOS
    /// have none, so the request is a no-op there).
    @Test("A chosen family's count badge draws tabular digits")
    func badgeDigitsAreTabular() throws {
        let family = "Apple Chancery"
        try #require(BarFont.isInstalled(family))
        func advances(_ font: NSFont) -> Set<CGFloat> {
            Set(
                ["1", "4", "8"].map {
                    ($0 as NSString).size(withAttributes: [.font: font])
                        .width
                }
            )
        }
        var shelf = KiwiShelf()
        shelf.fontFamily = family
        let text = shelf.textFont(ofSize: 12)
        try #require(advances(text).count > 1, "fixture is tabular")
        let badge = shelf.badgeFont(ofSize: 12, emphasis: .bold)
        #expect(advances(badge).count == 1)
    }

    /// Skia's axis speaks 0.48–3.2, not a weight number.
    @Test("A legacy normalized axis counts as none")
    func legacyAxisIsNone() throws {
        let skia = try #require(NSFont(name: "Skia-Regular", size: 12))
        #expect(BarFont.weightAxis(of: skia) == nil)
        #expect(BarFont.weightAxis(of: .systemFont(ofSize: 12)) != nil)
    }

    /// Webdings and Bodoni Ornaments have a glyph for every letter
    /// of their names — pictograms — so glyph presence alone
    /// cannot tell; Core Text's symbolic class does.
    @Test("Symbol fonts are told from text fonts")
    func drawsOwnName() throws {
        #expect(BarFont.drawsOwnName("Menlo"))
        #expect(BarFont.drawsOwnName(KiwiShelf.systemFontFamily))
        for symbol in ["Webdings", "Bodoni Ornaments"] {
            try #require(BarFont.isInstalled(symbol), "\(symbol)")
            #expect(!BarFont.drawsOwnName(symbol), "\(symbol)")
        }
    }

    /// One tolerance: a chip is offered exactly where the caption
    /// stays silent, so the two never disagree.
    @Test("A chip is offered exactly where the family draws it")
    func chipsAgreeWithRendering() throws {
        #expect(BarFont.sameWeight(480, 500))
        #expect(!BarFont.sameWeight(440, 500))
        for family in ["Menlo", "Helvetica Neue", "Zapfino"] {
            try #require(BarFont.isInstalled(family), "\(family)")
            for named in BarFontWeight.allCases {
                #expect(
                    BarFont.offers(weight: named.value, family: family)
                        == (BarFont.rendering(
                            family: family,
                            weight: named.value
                        ) == .exact),
                    "\(family) \(named)"
                )
            }
        }
    }

    /// SF Mono's axis starts near 295: a lighter ask draws clamped
    /// and says so; SF Pro's reaches 1.
    @Test("The system pair reads its real axis")
    func systemAxes() {
        let mono = BarFont.systemAxis(monospaced: true)
        guard
            case .nearestFace(let drawn) = BarFont.rendering(
                family: KiwiShelf.systemMonospacedFontFamily,
                weight: 100
            )
        else {
            Issue.record("SF Mono claimed to draw 100")
            return
        }
        #expect(drawn == mono.clamp(100))
        #expect(
            BarFont.rendering(family: KiwiShelf.systemFontFamily, weight: 100)
                == .exact
        )
    }

    /// Read once per family, kept until the font set changes.
    @Test("What a family has is kept until invalidated")
    func facesAreMemoized() throws {
        BarFont.invalidate()
        try #require(BarFont.isInstalled("Menlo"))
        #expect(BarFont.cache.faces["Menlo"] != nil)
        _ = BarFont.isInstalled("KiwiDesk No Such Family")
        #expect(BarFont.cache.missing.contains("KiwiDesk No Such Family"))
        BarFont.invalidate()
        #expect(BarFont.cache.faces.isEmpty)
        #expect(BarFont.cache.missing.isEmpty)
    }
}
