import Foundation
import Testing

@testable import KiwiDesk

/// The two things the #996 QA sitting cost an eye-confirm to
/// find, both invisible to every other guard because both are
/// about modifier ORDER rather than about which modifiers exist.
///
/// Neither can say what the ring looks like. What they hold is
/// the shape of the decision, so the next refactor that reorders
/// this chain is told what it broke instead of shipping it.
@Suite("Arrival focus ring (#996)")
struct ArrivalRingTests {
    /// The pane's OWN chain, scoped to `contentColumn`.
    ///
    /// Read file-wide, both order tests answer against whichever
    /// `.focusable()` comes first in the file: with an earlier
    /// one present, `paddingFollowsFocusable` goes FAIL-OPEN on
    /// the shipped bug and `focusableFollowsLayout` goes
    /// false-red on a correct chain (`guard-prover`, 2026-09-01).
    private func pane() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsView+Detail.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.count > 200, "the pane file read empty")
        let scope = try #require(
            SourceScan.declarationBody(
                after: "private var contentColumn: some View",
                in: source
            ),
            "`contentColumn` is gone from the pane file"
        )
        let squashed =
            scope
            .split(whereSeparator: \.isWhitespace).joined()
        // Scoping answers an earlier `.focusable()` in the FILE;
        // a second one inside this scope reproduces both failure
        // modes, so the scope holds exactly one.
        #expect(
            squashed.components(separatedBy: ".focusable()").count
                == 2,
            Comment(
                rawValue:
                    "`contentColumn` declares more than one "
                    + "`.focusable()`, so the order tests below "
                    + "answer against whichever comes first "
                    + "rather than against the pane's (#996)"
            )
        )
        return squashed
    }

    /// The ring is drawn at the FOCUSED view's bounds, so padding
    /// applied before `.focusable()` pads the focused view itself
    /// and puts the ring on the window's own edges — where both
    /// vertical sides are clipped away (owner eye-confirm,
    /// 2026-09-01). Order is the whole fix; the modifiers are
    /// unchanged either way, which is why nothing else sees it.
    @Test("the pane is padded after it is made focusable")
    func paddingFollowsFocusable() throws {
        let source = try pane()
        let focusable = try #require(
            source.range(of: ".focusable()"),
            "the pane is no longer focusable — #996's destination"
        )
        let padding = try #require(
            source.range(
                of: ".padding(SettingsMetrics.focusRingInset)"
            ),
            "the pane no longer insets its ring"
        )
        #expect(
            padding.lowerBound > focusable.upperBound,
            Comment(
                rawValue:
                    "the ring inset is applied BEFORE "
                    + "`.focusable()`, so the padded — larger — "
                    + "view is the focused one and the ring lands "
                    + "on the window's edges with both sides "
                    + "clipped (#996)"
            )
        )
    }

    /// `.focusable()` must also follow the two `.frame` calls:
    /// applied to the pre-layout content, the ring is drawn round
    /// a box the centring then clips, losing its leading edge.
    @Test("the pane is made focusable after it is laid out")
    func focusableFollowsLayout() throws {
        let source = try pane()
        let centred = try #require(
            source.range(
                of: ".frame(maxWidth:.infinity,alignment:.center)"
            ),
            "the content column no longer centres itself"
        )
        let focusable = try #require(
            source.range(of: ".focusable()"),
            "the pane is no longer focusable"
        )
        #expect(
            focusable.lowerBound > centred.upperBound,
            Comment(
                rawValue:
                    "`.focusable()` is applied before the column "
                    + "is sized and centred, so the ring is drawn "
                    + "round the pre-layout content and loses its "
                    + "leading edge to the centring (#996)"
            )
        )
    }

    /// Every control that OPTS INTO focus owes the refusal.
    ///
    /// Derived from the population, not from a list of the
    /// compliant: a list agrees only with itself, so adding a
    /// CORRECT control reds it (a speed bump) while adding an
    /// INCORRECT one — `.focusable()` with no refusal — leaves it
    /// green, which is the harm. `guard-prover` (2026-09-01)
    /// found one already in the tree that way.
    ///
    /// An exemption names what makes it right, the idiom
    /// `ReduceMotionGateTests` and `ActivationPolicySeamTests`
    /// already use here.
    @Test("every focusable custom control refuses a click")
    func clickRefusalCensus() throws {
        let allowed: [String: String] = [
            "SpaceAssignmentChip.swift":
                "UNRULED, not exempt: a drag-source chip whose "
                + "click-born ring nobody has judged yet. It "
                + "predates the refusal and is recorded here so "
                + "the question is visible rather than absent — "
                + "rule it, then either add the refusal or "
                + "replace this with the reason it does not."
        ]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        var raw: [String] = []
        for file in files {
            let name = file.lastPathComponent
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
            if source.contains("NSEvent.pressedMouseButtons") {
                raw.append(name)
            }
            // `.focusable(false)` is an opt-OUT: it removes a
            // stop rather than taking one, so it owes nothing.
            let optsIn =
                source.contains(".focusable(")
                && source.replacingOccurrences(
                    of: ".focusable(false)",
                    with: ""
                ).contains(".focusable(")
            guard optsIn, allowed[name] == nil else { continue }
            #expect(
                source.contains("ClickBornFocus.isClickBorn"),
                Comment(
                    rawValue:
                        "\(name) takes `.focusable(` and never "
                        + "refuses click-born focus, so it draws "
                        + "a keyboard ring on every click — the "
                        + "defect #991 removes, re-entering "
                        + "through a control. Consult "
                        + "`ClickBornFocus.isClickBorn`, or add "
                        + "an `allowed` entry saying what makes "
                        + "this control different."
                )
            )
        }
        // And the reading itself has ONE home per question: a
        // hand-rolled copy beside a view is how it drifts, and it
        // took two spellings to get right — the button state
        // alone misses a click completed on mouse-up.
        #expect(
            raw.sorted() == ["ClickBornFocus.swift"],
            Comment(
                rawValue:
                    "`NSEvent.pressedMouseButtons` is read in "
                    + "\(raw.sorted()) — route it through "
                    + "`ClickBornFocus.isClickBorn` (#996)"
            )
        )
    }
}
