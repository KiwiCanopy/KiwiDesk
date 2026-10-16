import Testing

@testable import KiwiDeskCore

/// The array step the scrolling and monocle rows share (#168,
/// #2103 ruling 30): one index along, past every skipped one,
/// wrapping only where asked, never back onto the origin.
@Suite("Navigation array step")
struct NavigationArrayStepTests {
    @Test("a plain step moves one along, and stops at an end")
    func plainStep() {
        #expect(
            Navigation.arrayStep(from: 1, step: 1, count: 4, wrap: false) == 2
        )
        #expect(
            Navigation.arrayStep(from: 1, step: -1, count: 4, wrap: false) == 0
        )
        #expect(
            Navigation.arrayStep(from: 3, step: 1, count: 4, wrap: false)
                == nil
        )
    }

    @Test("a step passes what it skips, wrapping where asked")
    func skipsAndWraps() {
        let odd: (Int) -> Bool = { $0 % 2 == 1 }
        #expect(
            Navigation.arrayStep(
                from: 0,
                step: 1,
                count: 5,
                wrap: false,
                skip: odd
            )
                == 2
        )
        #expect(
            Navigation.arrayStep(
                from: 4,
                step: 1,
                count: 5,
                wrap: false,
                skip: odd
            )
                == nil
        )
        #expect(
            Navigation.arrayStep(
                from: 4,
                step: 1,
                count: 5,
                wrap: true,
                skip: odd
            )
                == 0
        )
        #expect(
            Navigation.arrayStep(
                from: 0,
                step: -1,
                count: 5,
                wrap: true,
                skip: odd
            )
                == 4
        )
    }

    @Test("with everything else skipped there is no step")
    func nothingLeft() {
        let others: (Int) -> Bool = { $0 != 2 }
        #expect(
            Navigation.arrayStep(
                from: 2,
                step: 1,
                count: 4,
                wrap: true,
                skip: others
            )
                == nil
        )
        #expect(
            Navigation.arrayStep(from: 0, step: 1, count: 1, wrap: true) == nil
        )
    }
}
