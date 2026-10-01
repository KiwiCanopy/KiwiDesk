import AppKit
import CoreGraphics
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The shelf's font in Settings (#1681): the Bars preview carries
/// the draft's shelf, the picker pins the system pair and filters,
/// and the weight caption says what a family draws in place of the
/// stored weight.
@Suite("Bar font in Settings", .serialized)
@MainActor
struct BarFontSettingsTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    @Test("Both bars' preview specs carry the draft's font")
    func previewCarriesTheDraft() {
        var settings = TilingSettings()
        settings.kiwishelf.fontFamily = "Menlo"
        settings.kiwishelf.fontWeight = 540
        let tile = HomeCardBarsTile(settings: settings, scale: 1.8)
        let specs = [
            tile.spaceSpec(settings.spaceBarLook),
            tile.appSpec(
                settings.appBarLook(for: settings.appBarHosts[0]),
                vertical: false
            ),
        ]
        for spec in specs {
            #expect(spec.shelf.fontFamily == "Menlo")
            #expect(spec.shelf.fontWeight == 540)
        }
    }

    /// The strip DRAWS the draft's face, not only carries it. What
    /// is measured is the width of the label's white ink in the
    /// rendered strip — deterministic, unlike the bitmap's bytes,
    /// which vary render to render — so a strip hard-coding
    /// `.system(size:)` draws Menlo's label at System's width.
    @Test("The preview strip draws its text in the draft's face")
    func stripDrawsTheDraftFace() throws {
        let system = try Self.labelInkWidth(KiwiShelf.systemFontFamily)
        let again = try Self.labelInkWidth(KiwiShelf.systemFontFamily)
        let menlo = try Self.labelInkWidth("Menlo")
        #expect(system == again, "the measure is not stable")
        #expect(system > 20, "the label drew no ink")
        #expect(
            abs(menlo - system) >= 8,
            "Menlo \(menlo) px vs System \(system) px"
        )
    }

    /// Columns carrying the label's white ink in a rendered strip
    /// for `family`, from the first to the last.
    private static func labelInkWidth(_ family: String) throws -> Int {
        var shelf = KiwiShelf()
        shelf.fontFamily = family
        let spec = HomeCardBarsTile.BarSpec(
            fill: "#333333",
            highlight: "#88BB44",
            items: [
                HomeCardBarsTile.BarItem(
                    color: "#FFFFFF",
                    length: 80,
                    label: "Window 1234"
                )
            ],
            alignment: .start,
            spans: false,
            boxed: false,
            thickness: 28,
            corner: 6,
            itemCorner: 4,
            gap: 5,
            indicator: .edgeMark,
            outlineWidth: 1.8,
            edgeMarkWidth: 2.7,
            borderWidth: 0,
            borderColor: "#FFFFFF",
            fontSize: 14,
            shelf: shelf,
            sheen: 0
        )
        let renderer = ImageRenderer(
            content: BarStripView(
                spec: spec,
                edge: .top,
                vertical: false,
                scale: 2
            )
            .frame(width: 320, height: 40)
        )
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let rep = NSBitmapImageRep(cgImage: image)
        let inked = (0..<rep.pixelsWide).filter { x in
            (0..<rep.pixelsHigh).contains { y in
                guard
                    let c = rep.colorAt(x: x, y: y)?
                        .usingColorSpace(.deviceRGB)
                else { return false }
                return c.alphaComponent > 0.5 && c.redComponent > 0.8
                    && c.greenComponent > 0.8 && c.blueComponent > 0.8
            }
        }
        guard let first = inked.first, let last = inked.last else {
            return 0
        }
        return last - first + 1
    }

    /// Handed an installed list that carries neither system family
    /// first, the picker still leads with the pair, once each.
    @Test("The picker pins the system pair and filters by substring")
    func pickerFilters() {
        pinEnglish()
        let installed = [
            "Menlo", KiwiShelf.systemFontFamily, "Monaco", "Zapfino",
        ]
        let all = FontFamilyPicker.families(installed: installed, query: "")
        #expect(Array(all.prefix(2)) == KiwiShelf.systemFontFamilies)
        #expect(all.count == 5)
        #expect(
            FontFamilyPicker.families(installed: installed, query: "mon")
                == [KiwiShelf.systemMonospacedFontFamily, "Monaco"]
        )
    }

    @Test("The caption names the face a family draws instead")
    func nearestFaceCaption() {
        pinEnglish()
        #expect(
            BarFontText.weightCaption(
                family: "Menlo",
                rendering: .nearestFace(weight: 400),
                weight: 540
            ) == "Menlo has no weight 540, so it draws its “Regular” face."
        )
        #expect(
            BarFontText.weightCaption(
                family: "Menlo",
                rendering: .exact,
                weight: 700
            ) == nil
        )
    }

    /// The backstop: a face the chips name as the stored weight's
    /// own is never captioned as a substitute.
    @Test("No caption where the drawn face has the stored name")
    func captionBackstop() {
        pinEnglish()
        #expect(
            BarFontText.weightCaption(
                family: "Example",
                rendering: .nearestFace(weight: 460),
                weight: 540
            ) == nil
        )
    }

    /// #1859: a family of fixed faces greys the slider, saying so,
    /// and the row states the face drawn rather than the stored
    /// weight, which it keeps for the next family.
    @Test("A fixed-face family greys the slider at the drawn face")
    func fixedFacesGreySlider() throws {
        pinEnglish()
        try #require(BarFont.isInstalled("Menlo"))
        let menlo = FontWeightRow.WeightState(family: "Menlo", weight: 540)
        #expect(menlo.shown == 400)
        #expect(
            menlo.inert
                == "Menlo comes in fixed weights only — pick one above."
        )
        let system = FontWeightRow.WeightState(
            family: KiwiShelf.systemFontFamily,
            weight: 540
        )
        #expect(system.shown == 540)
        #expect(system.inert == nil)
    }

    /// The row reads every stated value off ONE `WeightState`, and
    /// the shared row greys the slider only while a reason is
    /// given — a helper the call site stopped reading would leave
    /// the clause above green.
    @Test("The weight row is wired through its one state")
    func weightRowWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        func squashed(_ path: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let row = try squashed(
            "Sources/KiwiDesk/Settings/Components/Bars/FontWeightRow.swift"
        )
        for needle in [
            "readout:String(state.shown)",
            "spokenValue:BarFontText.spokenWeight(state.shown)",
            "sliderInert:state.inert",
            "shown:state.shown",
            "get:{Double(state.shown)}",
            "selected:shown==named.value",
            "guardstate.inert==nilelse{returnnil}",
        ] {
            #expect(row.contains(needle), "FontWeightRow lost \(needle)")
        }
        let shared = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/SliderPresetRow.swift"
        )
        #expect(shared.contains(".modifier(SliderInert(reason:sliderInert))"))
        #expect(
            shared.contains(
                "content.modifier(GreyOut(active:true,help:reason))"
            )
        )
    }

    @Test("The weight slider speaks its number and its name")
    func spokenWeight() {
        pinEnglish()
        #expect(BarFontText.spokenWeight(540) == "540, Medium")
    }

    @Test("A missing family greys the weight row with its reason")
    func missingFamilyGreysWeight() {
        var settings = TilingSettings()
        settings.kiwishelf.fontFamily = "KiwiDesk No Such Family"
        #expect(
            BarsGates(settings: settings).fontWeightReason
                == .fontMissing(family: "KiwiDesk No Such Family")
        )
        settings.kiwishelf.fontFamily = KiwiShelf.systemFontFamily
        #expect(BarsGates(settings: settings).fontWeightReason == nil)
    }

    @Test("A symbol font's row keeps the system face")
    func symbolRowsFallBack() throws {
        try #require(BarFont.isInstalled("Webdings"))
        #expect(FontFamilyPicker.face(of: "Webdings") == nil)
        #expect(FontFamilyPicker.face(of: "Menlo") != nil)
    }

    /// An empty search sits on the stored family, a search on its
    /// first match — the keyboard's start either way.
    @Test("The highlight follows the search, back to the stored family")
    func highlightRule() {
        let list = ["Menlo", "Monaco"]
        #expect(
            FontFamilyPicker.highlight(
                query: "  ",
                selection: "Zapfino",
                families: list
            ) == "Zapfino"
        )
        #expect(
            FontFamilyPicker.highlight(
                query: "mon",
                selection: "Zapfino",
                families: list
            ) == "Menlo"
        )
        #expect(
            FontFamilyPicker.highlight(
                query: "zz",
                selection: "Zapfino",
                families: []
            ) == nil
        )
    }
}
