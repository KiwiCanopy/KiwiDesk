import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Monocle's "Maximize windows" in Settings (#2976): Simple's
/// picture reads the bars as the Space's layout does, and the greyed
/// App Bar in Monocle row's link line places its link. Main-actor
/// spend: two catalog reads.
@Suite("Monocle maximize windows: Settings (#2976)")
@MainActor
struct MonocleMaximizeGuiTests {
    @Test("Simple's picture reads the Space Bar per layout")
    func pictureReadsTheBarsPerLayout() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.monocle.maximizeWindows = true
        #expect(
            SimpleSpacePicture.drawn(settings, in: .monocle)
                .spaceBarStyle.visibility == .hidden
        )
        #expect(
            SimpleSpacePicture.drawn(settings, in: .bsp)
                .spaceBarStyle.visibility == .always
        )
    }

    @Test("The App Bar in Monocle link line places its link")
    func linkLinePlacesItsLink() {
        #expect(
            KiwiShelfCard.monocleMaximizesProse.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }
}
