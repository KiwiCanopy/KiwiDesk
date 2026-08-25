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
    private let small = CGSize(width: 1024, height: 768)

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

    @Test("a screen repeats only when its list cannot fill it")
    func repeatsOnlyWhenForced() {
        // Two things are tangled here and only one is avoidable.
        // A laptop's list holds two layouts, so a laptop granted
        // three spaces MUST repeat one — no fill can help. What
        // can be got wrong is which repeat and where it lands:
        // the refill used to restart at the top of the list and
        // put the duplicate next to its twin.
        //
        // Both fixtures give a two-entry list a post-lead quota
        // of two, which is the only shape that reaches the
        // second refill pass. Three identical laptops do NOT —
        // their shares are [3, 2, 2] and every post-lead quota
        // is one — so a fixture that looks like the obvious one
        // cannot observe this at all (code review, 2026-08-26).
        let fixtures: [[CGSize]] = [
            [laptop, CGSize(width: 1920, height: 1080), small],
            [laptop, laptop, small],
        ]
        for sizes in fixtures {
            let modes = StarterAllocation.modes(sizes: sizes)
            #expect(modes.count == sizes.count)
            #expect(modes.allSatisfy { !$0.isEmpty })
            for block in modes {
                // Adjacency is the whole assertion, and that is a
                // finding rather than a shortcut. A "distinct up
                // to capacity" check sat here first —
                // `Set(tiled).count == min(tiled.count,
                // reachable.count)` — and guard-prover showed it
                // was implied: on every block these fixtures
                // produce, the demand reduces to "not all of them
                // identical", which adjacency already forbids,
                // and on the single-space screens it cannot fail
                // at all. It would only bite on a block of three
                // drawn from three or more reachable layouts —
                // a wide screen holding three tiled spaces, which
                // needs a still wider screen beside it to take
                // the Floating host role. Add that fixture and
                // the assertion with it; do not add the
                // assertion alone (2026-08-26).
                let tiled = block.filter { $0 != .floating }
                for pair in zip(tiled, tiled.dropFirst()) {
                    #expect(pair.0 != pair.1, "adjacent: \(block)")
                }
            }
        }
    }
}
