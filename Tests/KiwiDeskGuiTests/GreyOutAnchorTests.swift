import Foundation
import Testing

/// #527: a block gate's explanation must stay reachable while
/// the block is dimmed — `.disabled` is cumulative, so every
/// `HelpButton` inside the gated subtree is dead. Each
/// block-gated editor therefore renders a live anchor OUTSIDE
/// the gate: the section header's `help:` or a disclosure
/// label. Split from `GreyOutParityTests` (§5: split suites
/// early); same lens — exact expressions, so losing one is a
/// conscious edit, never silent.
@Suite("Block-gate help anchors")
struct GreyOutAnchorTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// `count` pins how many times the anchor expression must
    /// occur: SpaceBarGroups and AppBarGroups each anchor TWO
    /// sections with the same expression, and a bare
    /// `contains` would stay green with one of the pair
    /// deleted — the cannot-fail needle #520 warned about.
    private let anchors: [(file: String, anchor: String, count: Int)] = [
        (
            "FocusBorderEditor.swift",
            "help: style.wrappedValue.enabled ? nil : offHelp",
            1
        ),
        (
            "SpaceBarGroups.swift",
            "help: enabled ? nil : offHelp",
            2
        ),
        (
            "AppBarGroups.swift",
            "help: anyBarShown ? nil : noBarHelp",
            2
        ),
        (
            "DragVisualsEditor.swift",
            "help: visual.wrappedValue.enabled",
            1
        ),
        (
            "NativeSpacesGroup.swift",
            "help: gatedOff && !gateHelp.isEmpty",
            1
        ),
        // The anchor is the live disclosure label, not a
        // section header — the `?` rides it while the rows
        // below are dimmed. The needle is the anchor's own
        // copy wiring, not a bare `HelpButton(`, which any
        // future per-row help button would satisfy.
        (
            "AppBarLayoutGroup.swift",
            "explanation: overridesDisabledHelp",
            1
        ),
        // Reduce Motion greys the whole Animations card; the
        // explanation rides the header `?` so it survives the dim.
        (
            "BehaviorSection.swift",
            "help: reduceMotion ? reduceMotionHelp : nil",
            1
        ),
    ]

    @Test("every block gate keeps a live help anchor")
    func blockGatesKeepTheirAnchor() throws {
        let files = try SourceScan.swiftSources(under: settingsDir)
        for (name, anchor, count) in anchors {
            let file = try #require(
                files.first { $0.lastPathComponent == name },
                "anchored editor file is gone: \(name)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let found =
                source.components(
                    separatedBy: anchor
                ).count - 1
            #expect(
                found >= count,
                Comment(
                    rawValue:
                        "\(name) has \(found) of \(count) gate "
                        + "anchor(s) `\(anchor)` — a greyed "
                        + "block's help must stay clickable "
                        + "outside the disabled subtree (#527)"
                )
            )
        }
    }
}
