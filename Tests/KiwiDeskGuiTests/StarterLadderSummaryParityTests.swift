import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Starter preset's summary names its rungs one by one, so the
/// English copy and `StarterLadder.blockModes` are two hand-written
/// copies of one list.
///
/// They drifted, silently and in the direction nothing could see.
/// `016cc50a` — a commit about the activation policy — also flipped
/// rung 2 from `.stack` to `.bsp` while every piece of prose kept
/// saying "Stack": the Settings summary, all eleven catalogs, and
/// the user guide. No gate could catch it. `extract-keys --check`
/// compares keys against call sites and the English literal was
/// untouched, so it stayed green; the catalogs were not stale, they
/// were faithfully translating a sentence that had become false.
///
/// The mode a preset assigns is not a detail a user can shrug off —
/// picking Starter is how someone learns what the layouts *are*, so
/// a rung that does not match its label teaches the wrong name for
/// the layout they are looking at.
///
/// **What this does not watch.** The rung list has four copies, and
/// this guard closes one pair: `blockModes` against the rendered
/// Settings summary. `StarterLadder`'s own docstring table,
/// `docs/user-guide.md`'s preset list and the #466 entry in
/// `docs/design-decisions.md` are prose, and all three were found
/// stale when this suite was written — the design-decisions one
/// since `cb817c52`, which is two shipped ladders ago. Scanning
/// prose for a mode list is brittle enough to be its own
/// false-confidence problem, so they stay on review instead. Read
/// that as a scope statement, not as coverage.
@Suite("Starter ladder summary parity", .serialized)
@MainActor
struct StarterLadderSummaryParityTests {
    /// Reads the rungs the way the ladder itself does, so this
    /// cannot be satisfied by a second hand-written list here.
    private var rungNames: [String] {
        let modes = StarterLadder.spaceModes(displayCount: 1)
        return (1...StarterLadder.spacesPerDisplay)
            .compactMap { modes[SpaceID($0)]?.displayName }
    }

    @Test("The summary names every rung, in ladder order")
    func summaryMatchesTheLadder() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }

        let summary = StarterLadder.standardLayout(displayCount: 1)
            .displaySummary
        #expect(!summary.isEmpty)

        // Walk forward through the sentence: each rung must appear,
        // and after the previous one. Position is the half that
        // matters — a summary listing the right five modes in the
        // wrong order still misdescribes which space is which.
        var cursor = summary.startIndex
        for name in rungNames {
            let hit = summary.range(
                of: name,
                range: cursor..<summary.endIndex
            )
            #expect(
                hit != nil,
                """
                "\(name)" is a Starter rung but the preset summary \
                does not name it, in order, after the rung before \
                it. Summary: "\(summary)"
                """
            )
            guard let hit else { return }
            cursor = hit.upperBound
        }
    }

    /// The ladder must not name one layout twice: the summary check
    /// above walks forward, so a duplicated mode could be satisfied
    /// by a single mention and the guard would stop watching one of
    /// the rungs.
    @Test("Every rung is a distinct layout mode")
    func rungsAreDistinct() {
        #expect(Set(rungNames).count == rungNames.count)
    }
}
