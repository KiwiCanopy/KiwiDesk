import AppKit
import Testing

@testable import KiwiDeskCore

/// **KiwiHub and the plates wear the Fill on glass where glass
/// draws and flat over their material where it does not** (#2569 ▸
/// amendment): the toggle and a Fill with colour decide whether,
/// the leaf as drawn decides on what, in one answer every reader
/// takes. The answer is pure; each tree hands it its own reads.
@Suite("Panel ground (#2569)")
struct PanelGroundTests {
    private func shelf(
        toggle: Bool = true,
        fill: String = "#14201CB3"
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.tintHubAndPlates = toggle
        shelf.fillColor = fill
        return shelf
    }

    private func ground(
        _ shelf: KiwiShelf,
        glass: Bool,
        reduced: Bool = false
    ) -> PanelGround {
        shelf.panelGround(glassDrawn: glass, reduceTransparency: reduced)
    }

    @Test("The toggle and a colour decide whether, the glass on what")
    func groundTable() {
        #expect(ground(shelf(), glass: true) == .glass)
        #expect(ground(shelf(), glass: false).frost != nil)
        #expect(ground(shelf(toggle: false), glass: true) == .untinted)
        #expect(ground(shelf(toggle: false), glass: false) == .untinted)
        #expect(ground(shelf(fill: "#14201C00"), glass: true) == .untinted)
        #expect(ground(shelf(fill: "#14201C00"), glass: false) == .untinted)
        #expect(ground(shelf(fill: ""), glass: false) == .untinted)
    }

    @Test("The frost wears the Fill's own alpha, flat")
    func frostKeepsTheAlpha() throws {
        let frost = try #require(ground(shelf(), glass: false).frost)
        #expect(abs(frost.alpha - 0xB3 / 255.0) < 0.001)
        #expect(abs(frost.red - 0x14 / 255.0) < 0.001)
        #expect(abs(frost.green - 0x20 / 255.0) < 0.001)
        #expect(abs(frost.blue - 0x1C / 255.0) < 0.001)
    }

    @Test("Reduce transparency makes the frost's Fill opaque")
    func reducedIsOpaque() throws {
        let frost = try #require(
            ground(shelf(), glass: false, reduced: true).frost
        )
        #expect(frost.alpha == 1)
        // A low alpha is the user's, kept where transparency is not
        // reduced, and no bar to wearing the Fill.
        let faint = try #require(
            ground(shelf(fill: "#14201C40"), glass: false).frost
        )
        #expect(abs(faint.alpha - 0x40 / 255.0) < 0.001)
    }

    @Test("The Fill's lightness pins the frost")
    func lightnessPins() throws {
        let dark = try #require(
            shelf(fill: "#14201C20").frostFill(opaque: false)
        )
        let light = try #require(
            shelf(fill: "#F2F2F7B3").frostFill(opaque: false)
        )
        #expect(dark.pin == .dark)
        #expect(light.pin == .light)
    }

    /// The bound a material can only improve on: the Fill bare at
    /// its stored alpha over white and over black, and opaque under
    /// Reduce transparency, each against the reading floor the
    /// glass fade holds.
    @Test("Every bundled palette's panel inks read on the flat Fill")
    @MainActor
    func bundledPalettesRead() throws {
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            var settings = TilingSettings()
            palette.apply(to: &settings)
            let shelf = settings.kiwishelf
            let opaque = LiquidGlassGate.opaque(shelf.fillColor)
            let cases: [(String, Bool, Double)] = [
                (shelf.fillColor, false, KiwiShelf.readingInkFloor),
                (opaque, false, KiwiShelf.readingInkFloor),
                (opaque, true, KiwiShelf.increasedReadingInkFloor),
            ]
            for (fill, increased, floor) in cases {
                for (ink, layer) in shelf.panelInks(
                    increaseContrast: increased
                ) {
                    let ratio = try #require(
                        shelf.worstContrast(ink, nil, on: fill, beneath: layer)
                    )
                    measured += 1
                    #expect(
                        ratio >= floor,
                        Comment(
                            rawValue: "\(palette.name) \(ink) on "
                                + "\(layer ?? "-") on \(fill): \(ratio)"
                        )
                    )
                }
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 12)
        #expect(measured > 0)
    }
}

/// The Core plates' material wears the Fill beneath its content and
/// takes the Fill's scheme; untinted, it follows the Appearance pick.
@Suite("Frost plate (#2569)")
@MainActor
struct FrostPlateTests {
    private func fill(_ hex: String, opaque: Bool = false) throws -> FrostFill
    {
        var shelf = KiwiShelf()
        shelf.fillColor = hex
        return try #require(shelf.frostFill(opaque: opaque))
    }

    @Test("A Fill is a wash beneath the content, pinned to its scheme")
    func washSitsBeneath() throws {
        let content = NSView()
        let plate = FrostPlate.make(
            content: content,
            fill: try fill("#14201CB3")
        )
        #expect(plate.subviews.count == 2)
        #expect(plate.subviews.last === content)
        let colour = try #require(FrostPlate.washColour(of: plate))
        #expect(abs(colour.alphaComponent - 0xB3 / 255.0) < 0.001)
        #expect(plate.appearance?.name == .darkAqua)
        let light = FrostPlate.make(
            content: NSView(),
            fill: try fill("#F2F2F7B3")
        )
        #expect(light.appearance?.name == .aqua)
    }

    @Test("No Fill is the bare material, following the pick")
    func untintedIsBare() {
        let content = NSView()
        let plate = FrostPlate.make(content: content, fill: nil)
        #expect(plate.subviews == [content])
        #expect(FrostPlate.washColour(of: plate) == nil)
        #expect(plate.appearance == nil)
    }

    /// The consumer: a slide page built with glass stood down wears
    /// the wash, and its panel no rim, which is glass's finish.
    @Test(
        "The slide's material plates wear the Fill",
        arguments: [true, false]
    )
    func slidePlatesWearIt(tinted: Bool) throws {
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.icon = { _ in nil }
        defer { overlay.end() }
        let press = SpaceSlideOverlay.Press(
            display: DisplayID(1),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
            axis: .horizontal,
            direction: 1,
            outgoing: [],
            holes: [],
            space: SpaceID("2"),
            glass: false,
            tint: nil,
            frost: tinted ? try fill("#14201CB3") : nil,
            pace: 1
        )
        _ = overlay.press(press)
        let play = try #require(overlay.play)
        #expect((play.panel as? ActiveGlassPanel)?.wearsActiveLook == false)
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
        let plates = Self.materials(in: play.strip)
        #expect(plates.count == 1)
        for plate in plates {
            #expect((FrostPlate.washColour(of: plate) != nil) == tinted)
        }
    }

    /// A second press inside one play carries its own frost: a
    /// toggle flipped mid-slide lands on the next page.
    @Test("A re-press takes the new press's frost")
    func rePressTakesTheFrost() throws {
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.icon = { _ in nil }
        defer { overlay.end() }
        let frost = try fill("#14201CB3")
        for wears in [false, true, false] {
            _ = overlay.press(
                SpaceSlideOverlay.Press(
                    display: DisplayID(1),
                    screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                    axis: .horizontal,
                    direction: 1,
                    outgoing: [],
                    holes: [],
                    space: SpaceID("2"),
                    glass: false,
                    tint: nil,
                    frost: wears ? frost : nil,
                    pace: 1
                )
            )
            #expect(overlay.play?.frost == (wears ? frost : nil))
        }
    }

    @Test("The brief pocket's material plate wears the Fill")
    func pocketPlateWearsIt() throws {
        let plate = BriefPocketPlateView(
            glass: false,
            tint: nil,
            frost: try fill("#14201CB3", opaque: true),
            image: nil
        )
        let materials = Self.materials(in: plate)
        #expect(materials.count == 1)
        let colour = try #require(
            materials.first.flatMap { FrostPlate.washColour(of: $0) }
        )
        #expect(colour.alphaComponent == 1)
    }

    private static func materials(in view: NSView) -> [NSVisualEffectView] {
        var found: [NSVisualEffectView] = []
        if let material = view as? NSVisualEffectView {
            found.append(material)
        }
        for sub in view.subviews { found += materials(in: sub) }
        return found
    }
}
