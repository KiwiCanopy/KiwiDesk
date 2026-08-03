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
    ///
    /// EXACT, not a floor. `>=` re-opens the same hole one size
    /// up: an expression that later gains a third occurrence
    /// could lose one of three and stay green. A gate or anchor
    /// gaining an occurrence is a conscious edit, so it updates
    /// the count.
    private let anchors: [(file: String, anchor: String, count: Int)] = [
        // The header `?` anchor now reads the resolver's reason
        // (#678 Phase 3): nil while the ring is on, the block
        // sentence while it is off — outside the greyed block.
        (
            "FocusBorderEditor.swift",
            "help: blockReason.map(GapsBordersGateHelp.sentence)",
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
        // Advanced Colours (#678 Phase 3). Every gate on this
        // page names a switch on ANOTHER page, so the header
        // anchor is not a nicety here — the hover string on a
        // dimmed row is the only other channel, and it cannot
        // say where to go without one.
        (
            "BarColorCards.swift",
            "help: allows ? nil : AdvancedColorsHelp",
            2
        ),
        (
            "StructureColorCards.swift",
            "help: gates.bordersHeaderHelp",
            1
        ),
        // The drag columns are subheadings, not sections, so
        // their live `?` is a `HelpButton` beside the title —
        // outside the dimmed rows either way.
        (
            "StructureColorCards.swift",
            "HelpButton(explanation: help, subject: title)",
            1
        ),
        // The column header `?` anchor reads the resolver's
        // enabled reason (#678 Phase 3): one call site, both
        // columns route through it.
        (
            "DragVisualsEditor.swift",
            "help: enabledReason.map(GapsBordersGateHelp.sentence)",
            1
        ),
        (
            "NativeSpacesGroup.swift",
            "help: gatedOff && !gateHelp.isEmpty",
            1
        ),
        // Reduce Motion greys the whole Animations card; the
        // explanation rides the header `?` so it survives the
        // dim. The card moved to Colours & Motion in #678
        // Phase 3, gate and anchor together.
        (
            "MotionCard.swift",
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
                found == count,
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
