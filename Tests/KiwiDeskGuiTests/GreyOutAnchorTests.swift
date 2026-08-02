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
    /// occur: a file anchoring TWO sections with one expression
    /// would keep a bare `contains` green with one of the pair
    /// deleted — the cannot-fail needle #520 warned about.
    private let anchors: [(file: String, anchor: String, count: Int)] = [
        (
            "FocusBorderEditor.swift",
            "help: style.wrappedValue.enabled ? nil : offHelp",
            1
        ),
        (
            "SpaceBarCard.swift",
            "help: allows ? nil : BarsGateHelp.spaceBarOff",
            1
        ),
        (
            "AppBarCard.swift",
            "help: allows ? nil : BarsGateHelp.noBarShown",
            1
        ),
        // The interim colour cards' headers, anchored where
        // their gates are resolved (`BarsSection`).
        (
            "BarsSection.swift",
            "help: on ? nil : BarsGateHelp.spaceBarOff",
            1
        ),
        (
            "BarsSection.swift",
            "help: shown ? nil : BarsGateHelp.noBarShown",
            1
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
