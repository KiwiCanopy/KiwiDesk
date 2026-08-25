import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which layout a starter setup's screens OPEN in (#1018).
///
/// Split from `StarterAllocationTests`, which owns the budget,
/// the share apportionment and the one Floating space: the lead
/// rule sits on top of all three and grew past the file ceiling
/// beside them. The fixtures are re-declared here on purpose —
/// per-file private helpers are the convention
/// (`.claude/rules/tests.md`), and these are inert sizes.
@Suite("Starter setup: which layout a screen opens in")
struct StarterLeadTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let pivoted = CGSize(width: 1440, height: 2560)

    @Test("#1018's worked example lands exactly")
    func workedExample() {
        // Supersedes 15b's, which had the 27" opening in Grid
        // and taking Stack beside it. Under #1018 the 27" leads
        // Scrolling and the laptop — the smaller screen — leads
        // Monocle; the laptop's second space then finds both its
        // own layouts spoken for and falls to Scrolling, which
        // is the budget forcing a repeat rather than a choice.
        let modes = StarterAllocation.modes(
            sizes: [laptop, screen27]
        )
        #expect(modes[0] == [.monocle, .scrolling])
        #expect(modes[1] == [.scrolling, .grid, .floating])
    }

    @Test("a solo screen leads Scrolling, whatever its size")
    func soloScreenLeadsScrolling() {
        // "At least one Scrolling space always exists": with one
        // screen there is no smaller screen to carry Monocle, so
        // the Monocle rule must not fire at all. A laptop alone
        // is the case that already looked right before #1018 and
        // so proves nothing on its own — the 27" and the
        // ultrawide are the ones that used to open in Grid and
        // Track.
        for size in [laptop, screen27, ultrawide, pivoted] {
            let modes = StarterAllocation.modes(sizes: [size])
            #expect(
                modes[0].first == .scrolling,
                "\(size) did not open in Scrolling"
            )
        }
    }

    @Test("the smallest screen leads Monocle, the rest Scrolling")
    func smallestLeadsMonocle() {
        // Three screens: the smallest carries Monocle and BOTH
        // others lead Scrolling — the repeat that the no-layout-
        // twice rule is carved out for.
        let modes = StarterAllocation.modes(
            sizes: [screen27, laptop, ultrawide]
        )
        #expect(modes[1].first == .monocle, "\(modes[1])")
        #expect(modes[0].first == .scrolling, "\(modes[0])")
        #expect(modes[2].first == .scrolling, "\(modes[2])")
    }

    @Test("equal widths: the later screen carries Monocle")
    func equalWidthsTieBreak() {
        // Two identical screens need a defined "smallest". It is
        // read off `fillOrder`'s far end, which puts the earlier
        // index first among equals — so the MAIN screen keeps
        // Scrolling and its twin takes Monocle. A tie-break that
        // ran the other way would open a fresh install's main
        // screen in Monocle.
        let modes = StarterAllocation.modes(
            sizes: [screen27, screen27]
        )
        #expect(modes[0].first == .scrolling)
        #expect(modes[1].first == .monocle)
    }

    @Test("the smallest screen leads Monocle even when wide")
    func smallestLeadsMonocleEvenWhenWide() {
        // The size rule is unconditional, and this is the case
        // where that bites: a 27" beside an ultrawide is "the
        // smallest", so it opens in Monocle although
        // `ScreenClass.desktop` lists Monocle nowhere — that
        // class is one of the two the layout list calls least in
        // need of it. Pinned so it stays a ruling rather than a
        // surprise; the alternative reading is that the Monocle
        // lead should also require a genuinely small screen.
        let modes = StarterAllocation.modes(
            sizes: [ultrawide, screen27]
        )
        #expect(modes[1].first == .monocle)
        #expect(!ScreenClass.of(screen27).layouts.contains(.monocle))
    }

    @Test("no screen opens two identical spaces")
    func noScreenRepeatsWithinItself() {
        // Three laptops: the middle one's whole list — Scrolling
        // and Monocle — is spoken for by the time it fills, and
        // the refill used to hand it back its own lead.
        let modes = StarterAllocation.modes(
            sizes: [laptop, laptop, laptop]
        )
        for block in modes {
            #expect(
                Set(block).count == block.count,
                "a screen drew a layout twice: \(block)"
            )
        }
    }
}
