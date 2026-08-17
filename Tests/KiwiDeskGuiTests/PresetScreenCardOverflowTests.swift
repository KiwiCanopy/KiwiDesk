import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The preset card's outline row is capped (#859).
///
/// It was not, until this change, while its own small twin always
/// has been: `screenCount` fed the `ForEach` directly, so a
/// `Starter` derived from five connected displays drew five 48 pt
/// outlines — 256 pt of them — inside a card whose grid minimum is
/// 200. Only `Starter` can reach it, the seven declared presets
/// being capped by hand at three screens, but
/// `StarterAllocation.budget`'s own docstring is explicit that
/// eleven displays gets eleven spaces one apiece, so the ceiling
/// is the desk's rather than the catalog's.
///
/// **What this suite cannot prove, stated rather than implied.**
/// The never-exactly-one correction inside `OverflowSplit` is
/// UNREACHABLE at the marker capacity this card passes
/// (`slots - 1`): the property holds here by the function's early
/// return, so a sweep at this shape would pass the clause by never
/// running it — 4b's own finding, and the reason
/// `OverflowSplitTests.neverHidesExactlyOne` sweeps the marker
/// capacity that selects the branch. This suite asserts the
/// property at the card's shape and the parity with the twin; the
/// clause itself belongs there.
@MainActor
@Suite("Preset screen card overflow")
struct PresetScreenCardOverflowTests {
    private func card(screens: Int) -> PresetScreenCard {
        PresetScreenCard(
            layout: StandardLayout(
                name: "Fixture",
                screenCount: screens,
                spaceCount: max(screens, 1),
                spaceModes: [:],
                spaceScreens: [:],
                isStandard: false,
                settings: TilingSettings()
            ),
            liveSizes: nil
        )
    }

    /// Written out rather than recomputed — the whole point of the
    /// cap is a table someone can read, and recomputing
    /// `OverflowSplit.shown` here would assert the card against
    /// the very function it calls.
    @Test("the row draws a bounded number of outlines")
    func theRowIsBounded() {
        let expected: [Int: (shown: Int, hidden: Int)] = [
            0: (0, 0),
            1: (1, 0),
            2: (2, 0),
            3: (3, 0),
            4: (4, 0),
            5: (3, 2),
            6: (3, 3),
            9: (3, 6),
            11: (3, 8),
        ]
        for (screens, want) in expected {
            let drawn = card(screens: screens)
            #expect(
                drawn.shown == want.shown,
                Comment(
                    rawValue:
                        "\(screens) screens drew \(drawn.shown) "
                        + "outlines, wanted \(want.shown)"
                )
            )
            #expect(drawn.hidden == want.hidden)
        }
    }

    /// The card and the saved-profile row are one grammar at two
    /// sizes, so they must hide the same number of screens. A cap
    /// that differed would make a five-screen profile fold
    /// differently in the list than on its card, which is the
    /// inconsistency #789 spent the branch removing.
    @Test("the card folds exactly as the saved row does")
    func theTwoMountsFoldAlike() {
        var compared = 0
        for screens in 0...12 {
            let pips = ProfileScreenPips(count: screens)
            #expect(card(screens: screens).shown == pips.shown)
            #expect(card(screens: screens).hidden == pips.hidden)
            compared += 1
        }
        #expect(compared == 13)
    }

    /// The property at this card's shape. It holds by the early
    /// return rather than by the correction — see the suite note.
    @Test("the row never claims to hide exactly one screen")
    func neverHidesExactlyOne() {
        var folded = 0
        for screens in 0...40 {
            let drawn = card(screens: screens)
            #expect(drawn.hidden != 1)
            if drawn.hidden > 0 { folded += 1 }
        }
        // The fold has to actually happen, or the assertion above
        // is true of a row that never overflows.
        #expect(folded > 0)
    }

    /// A hand-edited layout claiming a negative screen count must
    /// draw nothing rather than trap on the range.
    @Test("a negative screen count draws no outlines")
    func negativeScreenCountDrawsNothing() {
        let drawn = card(screens: -4)
        #expect(drawn.shown == 0)
        #expect(drawn.hidden == 0)
    }
}
