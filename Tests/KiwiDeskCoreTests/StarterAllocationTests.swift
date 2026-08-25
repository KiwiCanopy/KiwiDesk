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

        // A setup where a raw share falls BELOW one, which is the
        // only place the clamped-vs-floor remainder distinction
        // exists at all. Every other fixture here sits strictly
        // inside 1...3, where the two formulas are identical by
        // construction — so measuring the remainder against the
        // floor went unnoticed by this test and was caught only
        // by `widthOrderIsNeverInverted` (guard-prover,
        // 2026-08-11).
        let clamped = StarterAllocation.shares(
            widths: [1080, 1440, 1512, 1728, 2560, 3440],
            budget: 10
        )
        #expect(
            clamped[0] <= clamped[1],
            Comment(
                rawValue:
                    "a screen clamped up from zero out-ranked a "
                    + "wider one: \(clamped)"
            )
        )
        #expect(clamped.reduce(0, +) == 10)

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

    @Test("no layout twice, the deliberate lead excepted")
    func noRepeatsWhenAvoidable() {
        let modes = StarterAllocation.modes(
            sizes: [laptop, screen27, ultrawide]
        )
        // Within one screen there is still no repeat: two
        // identical spaces on one screen is a wasted space
        // however the budget fell out.
        for block in modes {
            #expect(
                Set(block).count == block.count,
                "one screen drew a layout twice: \(block)"
            )
        }
        // Across screens, Scrolling repeats ON PURPOSE (#1018):
        // it leads every screen but the smallest. Nothing else
        // may — a second Grid or a second Track here would mean
        // the fill stopped consulting `used`.
        let all = modes.flatMap { $0 }
        let repeated = Set(
            all.filter { mode in all.count(where: { $0 == mode }) > 1 }
        )
        #expect(repeated == [.scrolling], "repeated: \(all)")
    }

    @Test("same-shaped screens draw in positional order")
    func sameShapedScreensDrawInOrder() {
        // What is LEFT of "the largest picks first" after #1018,
        // stated honestly rather than staged.
        //
        // The old test paired two screens that wanted each
        // other's layouts and asserted the wider one kept its
        // head. That is now unreachable: every screen spends its
        // first slot on a lead, so a screen draws ONE item from
        // its own list unless its share is three. A screen CAN
        // hold three without being the widest — [1728, 1920,
        // 1024] apportions [3, 3, 1] — so the reason is not that
        // the Floating host monopolises it: it is that with one
        // draw each, the four shapes' first picks (grid, track,
        // stack, monocle) are all distinct and cannot collide,
        // and a screen drawing two is drawing them from a list
        // no other screen of a different shape shares.
        //
        // `fillOrder`'s DIRECTION is still guarded, one rule
        // over: `smallestScreen` reads its far end, so reversing
        // it moves the Monocle lead and reds the three lead
        // tests above. What is left to pin here is the tie-break
        // among equals — the two 27"s share one list, and the
        // earlier index draws first.
        let modes = StarterAllocation.modes(
            sizes: [ultrawide, screen27, screen27]
        )
        #expect(modes[1].dropFirst().first == .grid, "\(modes[1])")
        #expect(modes[2].dropFirst().first == .stack, "\(modes[2])")
        // Vacuity: they really do share a contested list, or
        // "draws first" decides nothing.
        #expect(ScreenClass.of(screen27).layouts.count >= 2)
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
