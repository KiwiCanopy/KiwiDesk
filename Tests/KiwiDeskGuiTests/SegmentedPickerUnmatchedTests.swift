import SwiftUI
import Testing

@testable import KiwiDesk

/// `SegmentedPicker` with a bound value matching no option.
///
/// Its docstring has always named that case (a hand-edited
/// config) and the pill has always hidden on it, but nothing
/// asserted it while nothing depended on it. The shared Corners
/// master now does: it binds an OPTIONAL and answers nil while
/// the ring's corner style and the drag pair's radius disagree
/// (#754), so "no segment selected" is the whole surfacing of a
/// state the user has to be able to see. A pill that fell back
/// to the first option instead would show Rounded over a square
/// ring — the defect the nil exists to end — with every other
/// guard green.
///
/// Read off the control's own `selectedIndex`, which is what
/// `slidingPill` branches on. `@MainActor` because that is a
/// `View` property: reading one off the main actor traps the
/// runner instead of failing an expectation.
@MainActor
@Suite("SegmentedPicker with an unmatched selection")
struct SegmentedPickerUnmatchedTests {
    private enum Shape: Hashable {
        case round
        case sharp
    }

    private func picker(
        _ selection: Shape?
    ) -> SegmentedPicker<Shape?> {
        SegmentedPicker(
            "Corners",
            selection: .constant(selection),
            options: [
                ("Round", Shape.round),
                ("Sharp", Shape.sharp),
            ]
        )
    }

    @Test("a matching value selects its segment")
    func matchedSelects() {
        #expect(picker(.round).selectedIndex == 0)
        #expect(picker(.sharp).selectedIndex == 1)
    }

    /// The load-bearing half: nil matches neither option, so no
    /// segment is selected and `slidingPill` draws nothing.
    @Test("a value matching no option selects nothing")
    func unmatchedSelectsNothing() {
        #expect(picker(nil).selectedIndex == nil)
    }
}
