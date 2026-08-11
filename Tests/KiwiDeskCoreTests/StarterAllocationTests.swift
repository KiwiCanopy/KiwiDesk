import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// How many spaces a starter setup creates and who gets which
/// layout (#678 Phase 4 pass 11, turn 15b).
@Suite("Starter allocation (#678 pass 11)")
struct StarterAllocationTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let pivoted = CGSize(width: 1440, height: 2560)

    // MARK: - Budget

    @Test("the budget ladder is 3 · 5 · 7 · 8 · 9, then +1")
    func budgetLadder() {
        #expect(StarterAllocation.budget(screenCount: 1) == 3)
        #expect(StarterAllocation.budget(screenCount: 2) == 5)
        #expect(StarterAllocation.budget(screenCount: 3) == 7)
        #expect(StarterAllocation.budget(screenCount: 4) == 8)
        #expect(StarterAllocation.budget(screenCount: 5) == 9)
        #expect(StarterAllocation.budget(screenCount: 6) == 10)
    }

    @Test("the cap holds, and min-one-per-screen outranks it")
    func capYieldsToTheFloor() {
        #expect(
            StarterAllocation.budget(screenCount: 8)
                == StarterAllocation.softCap
        )
        // The cap is on SPACES, so a screen never ends up with
        // nowhere for a window to resolve to.
        #expect(StarterAllocation.budget(screenCount: 11) == 11)
        #expect(StarterAllocation.budget(screenCount: 0) == 3)
    }

    // MARK: - Shares

    @Test("shares are proportional to width and sum to budget")
    func sharesApportion() {
        let shares = StarterAllocation.shares(
            widths: [laptop.width, screen27.width],
            budget: 5
        )
        // 15b's own worked example: the laptop takes two, the
        // 27" takes three.
        #expect(shares == [2, 3])
        #expect(shares.reduce(0, +) == 5)
    }

    @Test("every supported screen count apportions exactly")
    func sharesAlwaysSumToBudget() {
        let widths: [CGFloat] = [
            1728, 2560, 3440, 1920, 1440, 2560, 1080, 3840,
        ]
        for count in 1...widths.count {
            let slice = Array(widths.prefix(count))
            let budget = StarterAllocation.budget(
                screenCount: count
            )
            let shares = StarterAllocation.shares(
                widths: slice,
                budget: budget
            )
            #expect(
                shares.reduce(0, +) == budget,
                "\(count) screens: \(shares) ≠ \(budget)"
            )
            #expect(shares.allSatisfy { $0 >= 1 })
            #expect(
                shares.allSatisfy {
                    $0 <= StarterAllocation.maxShare
                },
                "\(count) screens exceeded the per-screen cap"
            )
        }
    }

    /// The apportionment must be PROPORTIONAL, not merely
    /// summing to the budget. The first cut re-ranked a fixed
    /// remainder array inside the repair loop and handed the
    /// whole deficit to one screen, which every existing
    /// assertion — sum, clamps, determinism — was blind to (code
    /// review, 2026-08-11).
    @Test("equal screens get equal shares, wider screens more")
    func sharesAreProportional() {
        // Two identical screens beside a wider one: the twins
        // must not differ, whatever the budget arithmetic does.
        let twins = StarterAllocation.shares(
            widths: [1080, 1080, 1728],
            budget: 7
        )
        #expect(twins[0] == twins[1], "identical screens: \(twins)")
        #expect(twins[2] >= twins[0], "the widest lost: \(twins)")

        // The narrowest screen may never out-rank a wider one.
        let mixed = StarterAllocation.shares(
            widths: [1080, 1512, 1512],
            budget: 7
        )
        #expect(
            mixed[0] <= mixed[1] && mixed[0] <= mixed[2],
            "the narrowest screen took the most: \(mixed)"
        )

        // Five identical screens split as evenly as the budget
        // allows — never [3,3,1,1,1].
        let five = StarterAllocation.shares(
            widths: Array(repeating: 1920, count: 5),
            budget: 9
        )
        #expect(
            (five.max() ?? 0) - (five.min() ?? 0) <= 1,
            "identical screens split unevenly: \(five)"
        )
    }

    /// Width order is never inverted, at any supported setup.
    @Test("a wider screen never gets fewer spaces than a narrower")
    func widthOrderIsNeverInverted() {
        let pool: [CGFloat] = [1080, 1440, 1512, 1728, 2560, 3440]
        for count in 2...pool.count {
            let widths = Array(pool.prefix(count))
            let budget = StarterAllocation.budget(screenCount: count)
            let shares = StarterAllocation.shares(
                widths: widths,
                budget: budget
            )
            for i in widths.indices {
                for j in widths.indices where widths[i] < widths[j] {
                    #expect(
                        shares[i] <= shares[j],
                        "\(count) screens: \(widths) → \(shares)"
                    )
                }
            }
        }
    }

    @Test("identical screens apportion deterministically")
    func identicalScreensAreStable() {
        let widths = [CGFloat](repeating: 1920, count: 3)
        let first = StarterAllocation.shares(
            widths: widths,
            budget: 7
        )
        let second = StarterAllocation.shares(
            widths: widths,
            budget: 7
        )
        #expect(first == second)
        #expect(first.reduce(0, +) == 7)
    }

    // MARK: - Modes

    @Test("15b's worked example lands exactly")
    func workedExample() {
        // "The 27″ takes Grid, Stack and Floating; the laptop
        // takes Scrolling and Monocle."
        let modes = StarterAllocation.modes(
            sizes: [laptop, screen27]
        )
        #expect(modes[0] == [.scrolling, .monocle])
        #expect(modes[1] == [.grid, .stack, .floating])
    }

    @Test("exactly one Floating space, on the largest screen")
    func oneFloatingOnTheLargest() {
        let sizes = [laptop, ultrawide, screen27]
        let modes = StarterAllocation.modes(sizes: sizes)
        let floats = modes.flatMap { $0 }.filter { $0 == .floating }
        #expect(floats.count == 1)
        #expect(modes[1].contains(.floating))
        #expect(!modes[0].contains(.floating))
        #expect(!modes[2].contains(.floating))
    }

    @Test("Floating yields when no screen has room beside it")
    func noFloatingWhenEveryShareIsOne() {
        // Eleven screens: every share is one, every screen is
        // doing a single job, and a space that tiles nothing
        // would cost a screen its only layout.
        let sizes = [CGSize](
            repeating: screen27,
            count: 11
        )
        let modes = StarterAllocation.modes(sizes: sizes)
        #expect(modes.count == 11)
        #expect(modes.allSatisfy { $0.count == 1 })
        #expect(!modes.flatMap { $0 }.contains(.floating))
    }

    @Test("a single screen still gets its Floating space")
    func singleScreenKeepsFloating() {
        for size in [laptop, screen27, ultrawide, pivoted] {
            let modes = StarterAllocation.modes(sizes: [size])
            #expect(modes[0].count == 3)
            #expect(
                modes[0].last == .floating,
                "\(size) lost its Floating space"
            )
        }
    }

    @Test("no layout twice while the lists can avoid it")
    func noRepeatsWhenAvoidable() {
        let modes = StarterAllocation.modes(
            sizes: [laptop, screen27, ultrawide]
        )
        let all = modes.flatMap { $0 }
        #expect(Set(all).count == all.count, "repeated: \(all)")
    }

    @Test("the largest screen picks first, so it is not starved")
    func largestPicksFirst() {
        // The two screens must COMPETE, or the claim is untested.
        // An earlier cut paired a 27" with an ultrawide and
        // asserted the ultrawide got Track — but Track is absent
        // from the desktop list entirely, so no fill order could
        // ever have taken it away, and reversing `fillOrder` left
        // this green (guard-prover, 2026-08-11).
        //
        // Pivoted and desktop both open on layouts the other also
        // wants — stack and grid — so whoever picks first keeps
        // its own head and the loser falls down its list. Shares
        // are [2, 3] and the 27" hosts Floating.
        let modes = StarterAllocation.modes(
            sizes: [pivoted, screen27]
        )
        // Widest first: the 27" keeps Grid, its own best.
        #expect(modes[1].first == .grid)
        // The pivoted screen fills second and finds BOTH its
        // heads taken — grid and stack are the 27"'s two — so it
        // falls to Monocle, third on its list. That is the cost
        // of picking second, and it is what makes the order
        // matter: reverse `fillOrder` and this becomes `.stack`
        // while the 27" drops to `.bsp`.
        #expect(modes[0].first == .monocle)
        // Vacuity: the heads really are contested, or "picks
        // first" decides nothing.
        let contested = Set(ScreenClass.pivoted.layouts)
            .intersection(ScreenClass.desktop.layouts)
            .subtracting([.floating])
        #expect(!contested.isEmpty)
    }

    @Test("every space gets a layout, and the total is the budget")
    func totalMatchesBudget() {
        let setups: [[CGSize]] = [
            [laptop],
            [laptop, screen27],
            [screen27, ultrawide, pivoted],
            [laptop, screen27, ultrawide, pivoted],
        ]
        for sizes in setups {
            let modes = StarterAllocation.modes(sizes: sizes)
            let total = modes.reduce(0) { $0 + $1.count }
            #expect(
                total
                    == StarterAllocation.budget(
                        screenCount: sizes.count
                    ),
                "\(sizes.count) screens produced \(total) spaces"
            )
            #expect(
                modes.allSatisfy { !$0.isEmpty },
                "a screen was left with no space"
            )
        }
    }

    @Test("no screens in, no screens out")
    func emptyIsEmpty() {
        #expect(StarterAllocation.modes(sizes: []).isEmpty)
        #expect(StarterAllocation.shares(widths: [], budget: 3) == [])
    }
}
