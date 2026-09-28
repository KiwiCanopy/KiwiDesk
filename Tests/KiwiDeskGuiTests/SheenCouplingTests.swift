import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The sheen's Settings shape (#1644, owner 2026-09-27): one
/// signed centre-origin slider beneath the Liquid Glass switch,
/// never greyed, and not coupled to it — the switch writes nothing
/// to the sheen and the sheen never moves the switch's reading.
@MainActor
@Suite("The sheen beside the Liquid Glass switch", .serialized)
struct SheenCouplingTests {
    @Test("the glass switch writes nothing to the sheen")
    func masterLeavesTheSheen() {
        for flip in [true, false] {
            for sheen: CGFloat in [-0.5, 0, 0.5] {
                let model = makeTestModel()
                model.liquidGlassMaster.wrappedValue = !flip
                model.config.settings.borderStyle.sheen = sheen
                model.liquidGlassMaster.wrappedValue = flip
                #expect(model.config.settings.borderStyle.sheen == sheen)
            }
        }
        #expect(
            !(SettingKey.masterWrites[.colours(.liquidGlassMaster)]
                ?? []).contains("settings.borderStyle.sheen")
        )
    }

    /// Any strength beside every glass leaf on still reads the
    /// switch as on: it is not a surface of the agreement.
    @Test("the sheen never moves the switch's reading")
    func sheenIsNotALeaf() {
        for sheen: CGFloat in [-1, 0, 1] {
            var settings = TilingSettings()
            settings.borderStyle.sheen = sheen
            let agreement = LiquidGlassAgreement(settings: settings)
            #expect(agreement.allOn)
            #expect(!agreement.differ)
        }
    }

    /// Its own row in the Glass card, beneath the switch, the
    /// census's escape from the card's Reduce-transparency grey,
    /// and no gate at all: it shows below macOS 26 too.
    @Test("the row sits beneath the switch, never greys or hides")
    func rowPlacement() {
        #expect(
            ColorsRowOrder.glassAtRest == [
                .colours(.liquidGlassMaster),
                .colours(.borderSheen),
            ]
        )
        let placement = SettingKey.colours(.borderSheen).placement
        #expect(placement.container == .glass)
        #expect(placement.exemptFromContainerGate)
        #expect(placement.gate == nil)
        #expect(GlassCard.rows.contains(.colours(.borderSheen)))
        #expect(
            GlassCard.rows.contains(.colours(.liquidGlassMaster))
                == AppBarStyle.glassAvailable
        )
    }

    /// The row is a search hit on every macOS, the pre-26 one
    /// included: the index drops only rows the census hides.
    @Test("the row is searchable on every macOS")
    func rowIsSearchable() {
        let indexed = Set(SettingsSearchIndex.rows().compactMap(\.key))
        #expect(indexed.contains(.colours(.borderSheen)))
    }

    /// The signed wording the readout, VoiceOver and the diff pill
    /// share.
    @Test("the readout and spoken value name the direction")
    func readoutWording() {
        LocalizationManager.shared.select("en")
        #expect(SettingsValueReadout.sheen(0.5) == "+50%")
        #expect(SettingsValueReadout.sheen(-0.5) == "\u{2212}50%")
        #expect(SettingsValueReadout.sheen(0) == "Off")
        #expect(SettingsValueReadout.sheenSpoken(0.5) == "Lighter by 50%")
        #expect(SettingsValueReadout.sheenSpoken(-0.25) == "Darker by 25%")
        #expect(SettingsValueReadout.sheenSpoken(0) == "Off")
    }

    /// With an origin the accent runs between the origin and the
    /// knob, either way; without one it runs from the leading edge.
    @Test("a signed slider fills from its origin, either way")
    func originFill() {
        let right = SettingsSlider.fillSpan(knob: 150, origin: 100)
        #expect(right.x == 100 && right.width == 50)
        let left = SettingsSlider.fillSpan(knob: 40, origin: 100)
        #expect(left.x == 40 && left.width == 60)
        let atOrigin = SettingsSlider.fillSpan(knob: 100, origin: 100)
        #expect(atOrigin.width == 0)
        let plain = SettingsSlider.fillSpan(knob: 40, origin: nil)
        #expect(plain.x == 0 && plain.width == 40)
    }

    /// The Sheen row hands its slider the origin — the wiring half,
    /// which the geometry clause above cannot see.
    @Test("the Sheen row's slider takes 0 as its origin")
    func rowPassesTheOrigin() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks/"
                    + "SheenRow.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let slider = try #require(
            SourceScan.callArguments(of: "SettingsSlider(", in: source)
        )
        #expect(slider.contains("origin: 0"))
        // The band is Core's, read rather than restated (gui.md
        // #1359): both ends name `sheenRange`, no literal.
        let range = try #require(
            slider.components(separatedBy: "range:").dropFirst().first?
                .components(separatedBy: "step:").first
        )
        #expect(
            range.components(separatedBy: "BorderStyle.sheenRange").count == 3
        )
        #expect(!range.contains { $0.isNumber })
    }

    /// The track draws the origin fill it computes: `fillSpan` is
    /// handed the drag-following knob centre and the origin, so the
    /// geometry clause above is what the slider renders.
    @Test("the track fills from its origin to the live knob")
    func trackPassesTheOrigin() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "SettingsSlider.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let track = try #require(
            SourceScan.declarationBody(after: "func track(", in: source)
        )
        let call = try #require(
            SourceScan.callArguments(of: "Self.fillSpan(", in: track)
        )
        #expect(call.contains("knob: center"))
        #expect(call.contains("origin: origin.map"))
        #expect(track.contains("let center = knobCenter(in: width)"))
        let center = try #require(
            SourceScan.declarationBody(after: "func knobCenter(", in: source)
        )
        #expect(center.contains("dragFraction"))
    }
}
