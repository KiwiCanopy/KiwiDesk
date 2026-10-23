import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Reveal row's note says Grow plays as Unfold exactly where
/// Core plays it so (#2556): Grow picked on a Boxed shelf.
@Suite("Bars Grow fallback note")
@MainActor
struct BarsGrowFallbackTests {
    private func gates(
        reveal: KiwiShelf.RevealStyle,
        background: KiwiShelf.BackgroundStyle
    ) -> BarsGates {
        var settings = TilingSettings()
        settings.kiwishelf.revealStyle = reveal
        settings.kiwishelf.backgroundStyle = background
        return BarsGates(settings: settings, guiManaged: true)
    }

    @Test("Only Grow on a Boxed shelf owes the note")
    func noteOnlyForBoxedGrow() {
        for reveal in KiwiShelf.RevealStyle.allCases {
            for background in KiwiShelf.BackgroundStyle.allCases {
                let expected = reveal == .grow && background == .boxed
                #expect(
                    gates(reveal: reveal, background: background)
                        .growPlaysAsUnfold == expected,
                    "\(reveal) on \(background)"
                )
            }
        }
    }
}
