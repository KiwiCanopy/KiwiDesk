import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// The Home cards' plate-era chrome (#786): the two deliberate
/// card heights, the desktop plate's shape and silence, the
/// plate↔tall-group parity and the stroke-above-clip order.
/// The palette hand-off's needle net split to
/// `HomeCardPaletteWiringTests` at the file ceiling.
///
/// This is the chrome suite `SettingsThemeMetricTests` requires
/// for the `cardHeight`/`cardHeightCompact` pair — both weights
/// named together, so they cannot drift apart unseen.
@Suite("Home card chrome")
struct HomeCardChromeTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Both heights, named together, with the relations that
    /// make them two REGISTERS rather than two numbers: the
    /// tall card must hold the whole plate plus a text band at
    /// least the size of nothing — and stay above the compact
    /// card, or the group split reads backwards.
    @Test("the two card heights hold their registers")
    func heightsHoldTheirRegisters() {
        #expect(SettingsTheme.cardHeight == 152)
        #expect(SettingsTheme.cardHeightCompact == 105)
        #expect(SettingsTheme.plateHeight == 92)
        #expect(
            SettingsTheme.cardHeight
                > SettingsTheme.cardHeightCompact
        )
        // The plate plus the text band's minimum (title row +
        // subtitle + paddings ≈ 60) is what the tall height IS;
        // a plate growing past the band is a card that clips
        // its own answer.
        #expect(
            SettingsTheme.cardHeight
                >= SettingsTheme.plateHeight + 56
        )
    }

    /// The height CHOICE derives from the one group partition —
    /// `HomeCardOrder.thisProfile` — never a second hand-kept
    /// list of which cards are tall.
    @Test("the tall register derives from the group partition")
    func tallDerivesFromTheGroup() throws {
        let card = try squashed("HomeCard.swift")
        #expect(
            card.contains(
                "height:tall?SettingsTheme.cardHeight"
                    + ":SettingsTheme.cardHeightCompact"
            )
        )
        #expect(
            card.contains(
                "vartall:Bool{"
                    + "HomeCardOrder.thisProfile"
                    + ".contains(destination)}"
            )
        )
    }

    /// The plate's frame is the theme's height on the theme's
    /// ground, silent to VoiceOver and inert to the pointer —
    /// the card is ONE button whose value is its subtitle, and
    /// the renderers inside carry AX elements of their own that
    /// must not leak into the card's voicing.
    @Test("the plate draws its frame and stays silent")
    func plateShapeAndSilence() throws {
        let plate = try squashed("HomeCardPlate.swift")
        #expect(
            plate.contains(
                ".frame(height:SettingsTheme.plateHeight)"
            )
        )
        #expect(
            plate.contains(
                ".background(SettingsTheme.previewPlate)"
            )
        )
        #expect(plate.contains(".accessibilityHidden(true)"))
        #expect(plate.contains(".allowsHitTesting(false)"))
    }

    /// A plate implies the tall group: the plate switch is a
    /// third hand-kept mirror of the group partition, and a
    /// plate added to a whole-app case would ship a 92 pt
    /// picture into a 105 pt card with every list guard green
    /// (architect review, 2026-08-09; parity-tests.md's
    /// past-two-mirrors rule).
    @Test("a plate implies the tall group")
    @MainActor
    func plateImpliesTheTallGroup() {
        let model = makeTestModel()
        var plated = 0
        for destination in SettingsDestination.allCases {
            guard
                HomeCardPlate.plate(
                    for: destination,
                    model: model
                ) != nil
            else { continue }
            plated += 1
            #expect(
                HomeCardOrder.thisProfile.contains(destination),
                Comment(
                    rawValue:
                        "\(destination) plates outside the "
                        + "tall group"
                )
            )
        }
        // Every profile card plates today; a card leaving the
        // partition is a decision, not a drift.
        #expect(plated == HomeCardOrder.thisProfile.count)
    }

    /// The card's border rides ABOVE the clip, after the plate:
    /// in the background it was painted over by the opaque
    /// plate for the top 92 pt of every plated card, silencing
    /// the rest hairline, the hover accent and the #760
    /// mode-gated frame at once (ui-designer blocker,
    /// 2026-08-09) — with `ModeGatedChromeTests` green, since
    /// it pins tokens and predicates, not paint order.
    @Test("the card stroke is painted above the plate")
    func strokeRidesAboveTheClip() throws {
        #expect(
            try squashed("HomeCard.swift").contains(
                ".clipShape(RoundedRectangle("
                    + "cornerRadius:SettingsTheme.cardRadius))"
                    + ".overlay(cardStroke)"
            )
        )
    }

    /// The grid the two heights live in: the 240–360 column
    /// band the plates were eye-confirmed at (ui-designer
    /// 2026-08-10 kept 360 as the ceiling when the four-column
    /// cap landed), the per-band cap, and the
    /// saturated grid centring — the width
    /// `MonitorArrangementFitTests`' card canvas is derived
    /// from the band's floor.
    ///
    /// The cap became the BAND's in #678 turn 17a, so this
    /// pins the two-source form — measurement AND ceiling,
    /// whichever is smaller. The ceiling's own values are
    /// `SettingsResponsiveOrderTests`' (they are arithmetic
    /// over the class, not chrome), and 4 is still the top of
    /// them, which is why this suite keeps the needle at all:
    /// a `min` dropped here would let a fifth column appear on
    /// a wide screen with that suite green.
    @Test("the grid keeps its column band")
    func gridKeepsItsBand() throws {
        let source = try squashed("HomeScreen.swift")
        #expect(
            source.contains(
                "GridItem(.flexible(minimum:240,maximum:360),"
                    + "spacing:16)"
            )
        )
        #expect(
            source.contains(
                "letcount=max(1,min(band.homeColumnCap,fit))"
            )
        )
        #expect(SettingsWidthClass.wide.homeColumnCap == 4)
        #expect(
            source.contains(
                ".frame(maxWidth:gridCap)"
                    + ".frame(maxWidth:.infinity,"
                    + "alignment:.center)"
            )
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }
}
