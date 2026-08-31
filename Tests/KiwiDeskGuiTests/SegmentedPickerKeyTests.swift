import Foundation
import Testing

@testable import KiwiDesk

/// A segmented control costs ONE Tab stop and answers ← / →,
/// which is two claims a source scan and some arithmetic can
/// hold between them — and neither can say focus arrived, so
/// #997's device confirm is the third leg, not an optional one.
@Suite("Segmented picker keyboard (#997)")
struct SegmentedPickerKeyTests {
    // MARK: - The arithmetic

    @Test("an arrow steps one segment and stops at the ends")
    func stepClampsAtBothEnds() {
        #expect(SegmentedPickerKeys.step(from: 0, by: 1, count: 3) == 1)
        #expect(SegmentedPickerKeys.step(from: 1, by: 1, count: 3) == 2)
        #expect(SegmentedPickerKeys.step(from: 1, by: -1, count: 3) == 0)
        // The ends swallow their own arrow rather than wrapping:
        // a native segmented control does not cycle, and a wrap
        // would jump the selection across the whole control on a
        // key the user pressed to nudge it.
        #expect(SegmentedPickerKeys.step(from: 2, by: 1, count: 3) == 2)
        #expect(SegmentedPickerKeys.step(from: 0, by: -1, count: 3) == 0)
    }

    @Test("an unmatched selection lands on the first option")
    func unmatchedSelectionLandsFirst() {
        // #754's nil: there is no index to step FROM, and
        // treating it as 0 would make ← land on 0 and → land on
        // 1, skipping the first option on one of the two keys.
        #expect(SegmentedPickerKeys.step(from: nil, by: 1, count: 3) == 0)
        #expect(SegmentedPickerKeys.step(from: nil, by: -1, count: 3) == 0)
    }

    @Test("an empty control has nowhere to land")
    func emptyControlRefuses() {
        #expect(SegmentedPickerKeys.step(from: nil, by: 1, count: 0) == nil)
        #expect(SegmentedPickerKeys.step(from: 0, by: 1, count: 0) == nil)
    }

    // MARK: - The stop count, which only the source can show

    /// The arithmetic above is reachable from the keyboard only
    /// if the track is the focus stop AND the segments have given
    /// theirs up. Both halves are needled, and each is read
    /// inside the declaration that must carry it rather than
    /// against the whole file.
    ///
    /// The scoping is not tidiness. Read file-wide, every needle
    /// below stays green while the focus pair is MOVED onto the
    /// segment — SwiftUI takes the last `.focusable`, so each
    /// segment is a stop again and the track is not, which is
    /// #997's original defect restored under a green guard
    /// (`guard-prover`, 2026-09-01; the same class `tests.md`
    /// records for `WorkflowSource.workflowStep`).
    @Test("the track takes one stop and the segments take none")
    func trackIsTheOnlyStop() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "SegmentedPicker.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let track = try body("private var track: some View", source)
        let segment = try body("private func segment(", source)
        let move = try body("private func move(", source)

        let needles: [(String, String, String)] = [
            (
                track, ".focusable(isEnabled).focused($focused)",
                "the TRACK is the control's one focus stop, and "
                    + "an unattached @FocusState moves focus "
                    + "nowhere"
            ),
            (
                track, ".onKeyPress(.leftArrow){move(-1)}",
                "← moves the selection"
            ),
            (
                track, ".onKeyPress(.rightArrow){move(1)}",
                "and → moves it the other way — the pair is what "
                    + "makes one stop enough to reach every "
                    + "segment"
            ),
            (
                segment, ".buttonStyle(.plain).focusable(false)",
                "and each SEGMENT gives its own stop up — "
                    + "without this the track's stop is ADDED to "
                    + "the per-segment ones, which is the "
                    + "reported defect plus one"
            ),
            (
                move, "SegmentedPickerKeys.step(",
                "and the move reads the ONE arithmetic the tests "
                    + "above hold, rather than a second copy "
                    + "beside the view"
            ),
        ]
        for (scope, needle, why) in needles {
            #expect(
                squashed(scope).contains(squashed(needle)),
                Comment(
                    rawValue:
                        "SegmentedPicker.swift lost `\(needle)` "
                        + "— \(why), and the failure is silent to "
                        + "everything except a person using the "
                        + "keyboard (#997)"
                )
            )
        }

        // The other direction, because SwiftUI takes the LAST
        // `.focusable`: a segment that opts back in re-earns its
        // stop while every positive needle above still matches.
        for banned in [".focusable(true)", ".focused("] {
            #expect(
                !squashed(segment).contains(squashed(banned)),
                Comment(
                    rawValue:
                        "a segment declares `\(banned)` — the "
                        + "last `.focusable` on a chain wins, so "
                        + "the segments are focus stops again and "
                        + "the control costs one press per "
                        + "segment (#997)"
                )
            )
        }
    }

    /// A focusable custom control owes a click-born-focus
    /// refusal, and this change makes the second one.
    ///
    /// The refusal is five readable lines and copying it is the
    /// cheaper move at two sites — but nothing was counting, so
    /// the third would be an omission rather than a decision.
    /// The set is held EXACTLY: a control that becomes focusable
    /// and skips the refusal reds here, and one that gains the
    /// refusal without needing it does too.
    ///
    /// `NSApp.currentEvent` — #991's seam for "did a keyboard
    /// drive this navigation" — is a DIFFERENT question and is
    /// counted by `SettingsInputSourceSeamTests`. "A mouse
    /// button is physically down" and "the current event is a
    /// key press" must not be merged: the second refuses
    /// programmatic focus, which this one must allow.
    @Test("who refuses click-born focus is a closed set")
    func clickBornRefusalCensus() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        var readers: [String] = []
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            if squashed(source).contains(
                "NSEvent.pressedMouseButtons"
            ) {
                readers.append(file.lastPathComponent)
            }
        }
        #expect(
            readers.sorted() == [
                "SegmentedPicker.swift", "SettingsSlider.swift",
            ],
            Comment(
                rawValue:
                    "the click-born-focus refusal is spelled in "
                    + "\(readers.sorted()) — a custom control "
                    + "that takes `.focusable` owes this refusal "
                    + "or it rings on every click (#991's family, "
                    + "#997). At a third copy, home it beside "
                    + "#991's input-source seam instead of adding "
                    + "an entry here."
            )
        )
    }

    /// The balanced body of `declaration`, so a needle is read
    /// against the subview that must carry it. Fails loudly
    /// rather than scanning "" if the declaration is renamed.
    private func body(
        _ declaration: String,
        _ source: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(
                after: declaration,
                in: source
            ),
            "`\(declaration)` is gone from SegmentedPicker.swift"
        )
    }

    private func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }
}
