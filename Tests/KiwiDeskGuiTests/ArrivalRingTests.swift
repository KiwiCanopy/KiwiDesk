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
    private func pane() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsView+Detail.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.count > 200, "the pane file read empty")
        return source.split(whereSeparator: \.isWhitespace).joined()
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

    /// Who refuses click-born focus, held as a closed set.
    ///
    /// A control that takes `.focusable()` and skips the refusal
    /// rings on every click — the defect #991 exists to remove,
    /// re-entering through a control rather than through a
    /// navigation. An entry here is a decision; a missing one is
    /// an omission nothing else would report.
    @Test("every focusable custom control refuses a click")
    func clickRefusalCensus() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        var consults: [String] = []
        var raw: [String] = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace).joined()
            if source.contains("ClickBornFocus.isClickBorn") {
                consults.append(file.lastPathComponent)
            }
            if source.contains("NSEvent.pressedMouseButtons") {
                raw.append(file.lastPathComponent)
            }
        }
        #expect(
            consults.sorted() == [
                "SettingsSlider.swift", "SettingsView+Detail.swift",
            ],
            Comment(
                rawValue:
                    "the click-born refusal is consulted by "
                    + "\(consults.sorted()) — a `.focusable()` "
                    + "control that skips it draws a ring on "
                    + "every click (#991, #996)"
            )
        )
        // And the reading itself has ONE home: a hand-rolled copy
        // beside a view is how the predicate drifts, and it took
        // two spellings to get right.
        #expect(
            raw == ["ClickBornFocus.swift"],
            Comment(
                rawValue:
                    "`NSEvent.pressedMouseButtons` is read in "
                    + "\(raw) — route it through "
                    + "`ClickBornFocus.isClickBorn`, which also "
                    + "reads the current event, a case the button "
                    + "state alone misses (#996)"
            )
        )
    }
}
