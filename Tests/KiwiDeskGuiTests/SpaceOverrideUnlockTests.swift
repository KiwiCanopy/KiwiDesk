import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Spaces half of the #678 8c capability unlock — the twin of
/// `ShortcutsCapabilityUnlockTests`, which pins the same rules for
/// the shortcut override column.
///
/// The trap: the cheapest gate is per ROW (`count > 0` for the
/// row's own Space), which strands every peer of the one Space
/// that carries an override. Every test below names which
/// property it holds. Until any override exists the editor opens
/// from each row's actions menu (#2654), so the button's absence
/// hides nothing.
///
/// Two properties are deliberately NOT tested here, because a
/// test of either would assert what the type system already says
/// (tests.md, "Not owed"): that the gate cannot alter what runs —
/// `isOffered` returns `Bool` and touches nothing — and that a
/// space override cannot unlock a deeper surface elsewhere —
/// `HomeCardOrder.isOffered` takes no `TilingSettings`, so the
/// override is not in its reach at all. Both were drafted, both
/// passed by construction rather than by observation, and a test
/// that cannot fail is worse than none (#406).
@MainActor
@Suite("Space override unlock (#678 8c)")
struct SpaceOverrideUnlockTests {
    /// Three spaces, so "the whole list" has peers to be wrong
    /// about — a single-space fixture would pass this suite while
    /// a per-row gate shipped.
    private let spaces = [
        SpaceID("1"), SpaceID("2"), SpaceID("3"),
    ]

    /// Settings carrying one BSP master-count override on
    /// `space`, and nothing else.
    private func settings(
        overriding space: SpaceID?
    ) -> TilingSettings {
        var settings = TilingSettings()
        if let space {
            var bsp = BspOverride()
            bsp.splitRatioH = 0.6
            settings.bsp.override[space] = bsp
        }
        return settings
    }

    // MARK: - The button is withheld until it is earned

    @Test("no override anywhere withholds the button")
    func withoutOverridesIsLocked() {
        #expect(
            !SpaceOverrideOffer.isOffered(
                settings: settings(overriding: nil),
                spaces: spaces
            )
        )
    }

    /// The door that keeps the editor reachable meanwhile: the
    /// row's actions menu, which every channel reads.
    @Test("the row menu opens the editor before any override")
    func rowMenuOpensTheEditor() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "SpacesSection+Customize.swift"
            )
        let raw = try String(contentsOf: url, encoding: .utf8)
        let body = SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(!body.isEmpty)
        #expect(
            body.contains(
                "funccontextActions(_space:SpaceID)->someView{"
                    + "Button(L(\"spaces.overrides.customize\","
                    + "\"Customize…\")){"
                    + "model.nav.spaceOverridesFocus=space}"
            )
        )
    }

    // MARK: - The whole list, not the overridden row

    /// The property a per-row gate breaks: one override unlocks
    /// EVERY row, including the two spaces that carry nothing.
    ///
    /// Asserted by asking the predicate about the whole list
    /// while only the middle space is overridden — a gate written
    /// as `count(for: thisRow) > 0` answers false for spaces 1
    /// and 3 and would fail here.
    @Test("one override unlocks the offer for every space")
    func oneOverrideUnlocksTheWholeList() {
        let settings = settings(overriding: spaces[1])
        #expect(
            SpaceOverrideOffer.isOffered(
                settings: settings,
                spaces: spaces
            ),
            "an override on space 2 must unlock rows 1 and 3 too"
        )
        // And it is the LIST that is consulted, not the space:
        // asking with only an unoverridden space present is the
        // locked answer, so the true above came from the list
        // rather than from some other input leaking through.
        #expect(
            !SpaceOverrideOffer.isOffered(
                settings: settings,
                spaces: [spaces[0]]
            ),
            "a list with no overridden space stays locked"
        )
    }

    /// The "collapsing away when the last override is cleared"
    /// half — a state a per-row gate cannot express at all.
    @Test("clearing the last override re-locks the offer")
    func clearingTheLastOverrideRelocks() {
        var live = settings(overriding: spaces[1])
        #expect(
            SpaceOverrideOffer.isOffered(
                settings: live,
                spaces: spaces
            )
        )
        live.bsp.override[spaces[1]] = nil
        #expect(
            !SpaceOverrideOffer.isOffered(
                settings: live,
                spaces: spaces
            ),
            "the offer must collapse with the last override"
        )
    }
}
