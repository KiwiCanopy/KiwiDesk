import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The sheen's Settings shape (#1644, owner 2026-09-27): its own
/// row beneath the Liquid Glass switch, coupled ONE way — glass on
/// ticks the sheen, glass off leaves it be — and never one of the
/// switch's leaves, so it cannot make the switch read "off".
@MainActor
@Suite("The sheen beside the Liquid Glass switch")
struct SheenCouplingTests {
    @Test("switching glass on ticks the sheen")
    func glassOnTicksTheSheen() {
        let model = makeTestModel()
        model.liquidGlassMaster.wrappedValue = false
        model.config.settings.borderStyle.sheen = false
        model.liquidGlassMaster.wrappedValue = true
        #expect(model.config.settings.borderStyle.sheen)
    }

    @Test("switching glass off leaves the sheen as it is")
    func glassOffLeavesTheSheen() {
        for sheen in [true, false] {
            let model = makeTestModel()
            model.liquidGlassMaster.wrappedValue = true
            model.config.settings.borderStyle.sheen = sheen
            model.liquidGlassMaster.wrappedValue = false
            #expect(model.config.settings.borderStyle.sheen == sheen)
        }
    }

    /// The sheen off beside every glass leaf on still reads the
    /// switch as on: it is not a surface of the agreement.
    @Test("the sheen never moves the switch's reading")
    func sheenIsNotALeaf() {
        var settings = TilingSettings()
        settings.borderStyle.sheen = false
        let agreement = LiquidGlassAgreement(settings: settings)
        #expect(agreement.allOn)
        #expect(!agreement.differ)
        #expect(
            !(SettingKey.masterWrites[.colours(.liquidGlassMaster)]
                ?? []).contains("settings.borderStyle.sheen")
        )
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
}
