import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shelf border's colour row on Advanced Colours (#1679):
/// greyed while the border is off, with its reason as a live link
/// to Bars beneath the grid — the #1310 shape — only while a bar
/// shows, since with none the card's header carries the reason.
@Suite("Shelf border colour gate")
@MainActor
struct ShelfBorderColorGateTests {
    private static func settings(
        border: Bool,
        barShows: Bool = true
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.border = border
        settings.spaceBarStyle.enabled = barShows
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        return settings
    }

    @Test("The row greys, and links, only while the border is off")
    func gateFollowsTheSwitch() {
        let off = AdvancedColorsGates(settings: Self.settings(border: false))
        #expect(off.shelfBorderOff)
        #expect(off.shelfBorderNeedsReference)
        let on = AdvancedColorsGates(settings: Self.settings(border: true))
        #expect(!on.shelfBorderOff)
        #expect(!on.shelfBorderNeedsReference)
    }

    @Test("With no bar shown the header's reason stands instead")
    func headerOutranksTheLink() {
        let gates = AdvancedColorsGates(
            settings: Self.settings(border: false, barShows: false)
        )
        #expect(gates.shelfBorderOff)
        #expect(!gates.shelfBorderNeedsReference)
    }

    /// One branch, one value (`CrossReferenceRowSlotTests`).
    @Test("The border row's prose places its link")
    func prosePlacesItsLink() {
        #expect(
            AdvancedColorsHelp.shelfBorderReference.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }

    /// The census gate names the switch, so a search hit and the
    /// diff narrate the row as the border's.
    @Test("The census gates the colour and the width on the switch")
    func censusGates() {
        let gated = SettingKey.kiwishelf(.border)
        #expect(
            KiwiShelfKey.borderColor.placement.gate?.settings
                .contains(gated) == true
        )
        #expect(
            KiwiShelfKey.borderWidth.placement.gate?.settings
                == [gated]
        )
    }
}

/// The Bars preview draws the draft's border (#1679): both bars'
/// specs carry its width at the frame's scale — nothing while the
/// switch is off — and its colour.
@Suite("Shelf border in the Bars preview")
@MainActor
struct ShelfBorderPreviewTests {
    private static let scale: CGFloat = 1.8

    private static func tile(border: Bool) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.kiwishelf.border = border
        settings.kiwishelf.borderWidth = 3
        settings.kiwishelf.borderColor = "#1C1C1E"
        return HomeCardBarsTile(settings: settings, scale: scale)
    }

    private static func specs(
        _ tile: HomeCardBarsTile
    ) -> [HomeCardBarsTile.BarSpec] {
        [
            tile.spaceSpec(tile.settings.spaceBarLook),
            tile.appSpec(
                tile.settings.appBarLook(
                    for: tile.settings.appBarHosts[0]
                ),
                vertical: false
            ),
        ]
    }

    @Test("Both bars' specs carry the draft's border")
    func specsFollowTheDraft() {
        let unit = HomeCardBarsTile.indicatorPerPoint * Self.scale
        for spec in Self.specs(Self.tile(border: true)) {
            #expect(spec.borderWidth == 3 * unit)
            #expect(spec.borderColor == "#1C1C1E")
        }
    }

    @Test("A border switched off draws no stroke")
    func offDrawsNothing() {
        for spec in Self.specs(Self.tile(border: false)) {
            #expect(spec.borderWidth == 0)
        }
    }
}
