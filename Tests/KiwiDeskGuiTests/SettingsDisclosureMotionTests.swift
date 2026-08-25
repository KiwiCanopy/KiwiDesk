import Foundation
import Testing

@testable import KiwiDesk

/// The drawer's motion is the chevron's ALONE (#961).
///
/// Opening a drawer inserts `configuration.content`, which
/// rebuilds the AX element list under the hosting view — that
/// part is what opening a drawer IS, and no arrangement of the
/// style avoids it. Running the toggle inside a transaction
/// stretched that rebuild across the animation's whole 0.18 s,
/// moving the accessibility frame of every element below the
/// drawer on every frame of it, and VoiceOver answered a moving
/// tree by re-resolving the element under its cursor and
/// speaking it again — so opening an accordion repeated
/// whatever had last been announced, anywhere on the page.
///
/// Split from `SettingsDisclosureHeaderTests` rather than added
/// to it: that suite is the #956 composition census, and adding
/// these clauses to it crossed the §2.1 hard ceiling outright —
/// `scripts/lint.sh` refused the commit, which is how the split
/// was decided rather than by taste.
///
/// **It reads ONE file**, so a transaction reaching the toggle
/// from outside it is invisible: a call site that wraps its own
/// `isExpanded` binding in `withAnimation`, or an ancestor
/// `.animation(_:value:)` over the group's subtree, reproduces
/// #961 exactly with this file byte-identical and this suite
/// green (guard-prover). Widening the scan to every
/// `withAnimation` in the GUI tree would flag the many
/// legitimate ones, so the bar is a review one: a drawer's
/// expansion is animated by the chevron and by nothing else.
///
/// **The same stated limit applies here**, and harder than
/// usual. This is a token match over one squashed file, so it
/// says the transaction is gone; it cannot say VoiceOver
/// stopped repeating, which only a device session says. #961
/// carries one, and it must be run with Reduce Motion BOTH
/// ways: the repeat surviving with Reduce Motion on is what
/// would show the animation was never the whole mechanism.
@Suite("Settings disclosure motion (#961)")
struct SettingsDisclosureMotionTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    private static let styleFile =
        "Sources/KiwiDesk/Settings/Components/Common/"
        + "SettingsDisclosureStyle.swift"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = Self.root
            .appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        // Non-vacuity: a scan over an unreadable or empty file
        // passes every `!contains` clause below for free.
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// Both halves, because they fail apart. Dropping the
    /// toggle's transaction and forgetting to move the motion
    /// leaves a drawer that snaps open with a chevron that
    /// snaps too — losing the rotating cue `#956` ruled is the
    /// header's resting affordance, with no VoiceOver gain to
    /// show for it.
    @Test("the drawer's motion is the chevron's alone")
    func toggleRunsOutsideATransaction() throws {
        let style = try squashed(Self.styleFile)
        // Non-vacuity for the negative clause: the file really
        // is the one that toggles the drawer.
        #expect(
            style.contains("configuration.isExpanded.toggle()")
        )
        // Every in-file spelling that would animate the
        // expansion, not just the one the fix removed: a
        // `.transaction` block sets the same animation, and an
        // `.animation` keyed on `configuration.isExpanded`
        // animates the LAYOUT rather than the chevron.
        #expect(
            !style.contains("withAnimation(")
                && !style.contains(".transaction{")
                && !style.contains(
                    "value:configuration.isExpanded)"
                ),
            Comment(
                rawValue:
                    "the toggle is back inside a transaction — "
                    + "an animated insert moves every "
                    + "accessibility frame below the drawer for "
                    + "its whole duration (#961)"
            )
        )
        // The easing's DURATION is deliberately not pinned:
        // retuning it is a taste change with no accessibility
        // content, and a literal here would red as a text
        // mismatch under a message about VoiceOver. What has
        // to hold is the SCOPING — an `.animation` keyed on the
        // chevron's own `expanded`, gated by Reduce Motion.
        #expect(
            style.contains(
                ".animation(reduceMotion?nil:"
            ) && style.contains(",value:expanded)"),
            Comment(
                rawValue:
                    "the chevron's scoped animation is gone, so "
                    + "the drawer has no motion at all — the "
                    + "rotating cue is #956's ruling"
            )
        )
    }
}
