import CoreGraphics
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A point slider under Auto shows the size Auto draws where its
/// caller can say (#1713): the thumb sits at it, the readout shows
/// it, and VoiceOver hears it as automatic. Without that value it
/// keeps the plain "Automatic".
@Suite("Point slider under Auto")
@MainActor
struct PtSliderAutoValueTests {
    private static func slider(
        value: CGFloat,
        autoValue: CGFloat?
    ) -> PtSlider {
        PtSlider(
            label: "x",
            value: .constant(value),
            range: 1...64,
            autoAtZero: true,
            autoValue: autoValue
        )
    }

    @Test("Auto with a known size shows and speaks that size")
    func autoShowsItsSize() {
        LocalizationManager.shared.select("en")
        let slider = Self.slider(value: 0, autoValue: 36)
        #expect(slider.sliderPosition == 36)
        #expect(slider.readoutText == "36 pt")
        #expect(slider.spokenText == "Automatic, 36 pt")
    }

    @Test("Auto without a known size keeps the word")
    func autoWithoutSizeKeepsTheWord() {
        LocalizationManager.shared.select("en")
        let slider = Self.slider(value: 0, autoValue: nil)
        #expect(slider.readoutText == "Automatic")
        #expect(slider.spokenText == "Automatic")
    }

    @Test("A set size ignores the automatic one")
    func setSizeIgnoresAuto() {
        LocalizationManager.shared.select("en")
        let slider = Self.slider(value: 24, autoValue: 36)
        #expect(slider.sliderPosition == 24)
        #expect(slider.readoutText == "24 pt")
        #expect(slider.spokenText == "24 pt")
    }
}
