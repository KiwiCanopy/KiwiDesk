import Foundation
import Testing

@testable import KiwiDesk

/// Home's profile chips answer "which one wins" (#859).
///
/// Two defects lived in `HomeCardPreview.profileChips` until this
/// change, and both were #789's own arguments surviving on a second
/// surface:
///
/// - it sliced **raw** `profileSummaries`, which is
///   `allProfiles()`'s unordered read, while every other consumer
///   takes `ProfilesFamilyRows.orderedProfiles` — so the card could
///   hide the live-matching profile behind a "+N" and show three
///   that match nothing, under a doc comment claiming it answered
///   which one wins;
/// - it computed `count - cap` by hand, so five profiles drew four
///   chips and "+1" — the one thing the shared grammar forbids, the
///   marker taking a slot of its own precisely so it never claims
///   to hide exactly one.
///
/// The behaviour half is asserted over the seam plus the split
/// rather than over the view, `profileChips` being private and a
/// `some View` with nothing readable on it. The wiring half is the
/// scan below, and the two fail apart: the ordering property would
/// still hold if the view stopped calling the seam and sorted
/// inline, and the scan would still pass if the sort itself broke.
/// `@MainActor` because `HomeCardPreview` is: reading its cap off
/// the main actor traps the runner rather than failing an
/// expectation (gui.md ▸ a live preview that takes a window count).
@MainActor
@Suite("Home profile chips")
struct HomeCardProfileChipsTests {
    private func summary(
        _ name: String,
        count: Int,
        matchesLive: Bool = false,
        matchesCount: Bool = false
    ) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: matchesLive,
            matchesConnectedCount: matchesCount,
            openingModes: [],
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    /// The chips a given raw list draws, as names — the two
    /// production steps in the order the view takes them.
    private func chips(_ raw: [ProfileSummary]) -> [String] {
        let ordered = ProfilesFamilyRows.orderedProfiles(raw)
        let visible = OverflowSplit.shown(
            of: ordered.count,
            fitting: HomeCardPreview.chipCap,
            withMarker: HomeCardPreview.chipCap - 1
        )
        return ordered.prefix(visible).map(\.name)
    }

    /// The defect, as a test: the winner sits LAST in the raw
    /// order and past the cap, so a `prefix` of the unordered list
    /// cannot show it.
    ///
    /// Swept across the counts either side of the cap — the
    /// parameter that selects whether a marker appears at all — so
    /// the claim is not proven only at the one size where the fold
    /// happens to trigger.
    @Test("the winning profile is never hidden behind the marker")
    func theWinnerIsAlwaysShown() {
        var folded = 0
        for total in 1...9 {
            // The winner takes the WORST count, so only
            // `matchesLive` can lift it.
            //
            // It was the other way round — winner `count: 1`,
            // others `count: 9` — and that made this test INERT:
            // the third sort key reproduced the same order, so
            // neutralising `matchesLive` at the seam left the whole
            // suite green (guard-prover, 2026-08-17). A test named
            // for the winning profile that could not see the key
            // that makes one win.
            var raw = (1..<total).map {
                summary("other\($0)", count: 1)
            }
            raw.append(
                summary("winner", count: 99, matchesLive: true)
            )
            let drawn = chips(raw)
            #expect(
                drawn.contains("winner"),
                Comment(
                    rawValue:
                        "\(total) profiles: the display-matching "
                        + "profile fell behind the +N"
                )
            )
            #expect(drawn.first == "winner")
            if drawn.count < raw.count { folded += 1 }
        }
        // The fold must actually happen somewhere in the sweep, or
        // every assertion above is about a list that fits.
        #expect(folded > 0)
    }

    /// Written out rather than recomputed: the cap is 4, so five
    /// profiles draw three chips and "+2" — never four and "+1".
    @Test("five profiles draw three chips, not four")
    func fiveProfilesGiveUpASlot() {
        let raw = (1...5).map { summary("p\($0)", count: $0) }
        #expect(chips(raw).count == 3)
        #expect(chips(Array(raw.prefix(4))).count == 4)
        #expect(chips(Array(raw.prefix(1))).count == 1)
    }

    /// The property at THIS surface's shape. Like the preset
    /// card's, it holds by `OverflowSplit`'s early return rather
    /// than by the never-exactly-one correction, which is
    /// unreachable at `markerCapacity == capacity - 1` — deleting
    /// that correction leaves this green and reds
    /// `OverflowSplitTests` instead (guard-prover confirmed both).
    /// Read it as pinning what Home draws, not as coverage of the
    /// shared clause.
    @Test("no count leaves exactly one profile hidden")
    func neverHidesExactlyOne() {
        for total in 0...20 {
            let raw = (0..<total).map { summary("p\($0)", count: 1) }
            #expect(total - chips(raw).count != 1)
        }
    }

    // MARK: - The view takes those two steps

    @Test("the card consults the family seam and the split")
    func theCardConsultsTheSeamAndTheSplit() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPreview.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()

        #expect(source.count > 500)
        #expect(
            source.occurrences(
                of: "ProfilesFamilyRows.orderedProfiles("
            ) == 1
        )
        #expect(source.occurrences(of: "OverflowSplit.shown(") == 1)
        // The cap goes through the named constant, so the split and
        // the tests above cannot be reading different numbers.
        #expect(source.occurrences(of: "fitting:chipCap") == 1)
        // The defect's own spelling. `ruleIcons` in the same file
        // is a KNOWN non-adopter on a different card and keeps its
        // `prefix(5)`, so the needle names the profile cap exactly
        // rather than banning a bare `prefix(`.
        //
        // Deliberately NOT banning `summaries.count - shown.count`:
        // that subtraction is now correct, because `shown` is what
        // `OverflowSplit` returned rather than a hand-rolled
        // `prefix`. Banning the arithmetic would guard the shape of
        // the old bug instead of its cause.
        #expect(source.occurrences(of: "summaries.prefix(4)") == 0)
    }
}
