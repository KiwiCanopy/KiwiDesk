import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Reveal row's note narrates Core's own verdict (#2556): every
/// style Core plays in place of the pick is the one the note names,
/// so a new replacement in `playedRevealStyle` reds here until it
/// owes its own sentence.
@Suite("Bars Grow fallback note")
@MainActor
struct BarsGrowFallbackTests {
    @Test("The note covers exactly the replacements Core plays")
    func noteMatchesCore() {
        for reveal in KiwiShelf.RevealStyle.allCases {
            for background in KiwiShelf.BackgroundStyle.allCases {
                var settings = TilingSettings()
                settings.kiwishelf.revealStyle = reveal
                settings.kiwishelf.backgroundStyle = background
                let shelf = settings.kiwishelf
                let replaced = shelf.playedRevealStyle != reveal
                let note = BarsGates(settings: settings, guiManaged: true)
                    .growPlaysAsUnfold
                #expect(note == replaced, "\(reveal) on \(background)")
                // The sentence names Boxed as the cause.
                if note { #expect(background == .boxed) }
            }
        }
    }

    @Test("Core plays Grow as Unfold on Boxed alone")
    func coreVerdict() {
        var shelf = KiwiShelf()
        shelf.revealStyle = .grow
        #expect(shelf.playedRevealStyle == .grow)
        shelf.backgroundStyle = .boxed
        #expect(shelf.playedRevealStyle == .unfold)
    }
}
