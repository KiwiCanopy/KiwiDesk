import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a schematic's frame is allowed to be (#753).
///
/// Two halves of one decision, and they fail apart. The first is
/// arithmetic: Scrolling reserves canvas for its off-monitor
/// ghosts, and reserving it at `.tile` drew the monitor at half
/// the size of every sibling's outline — the thumbnail that read
/// as broken in the layout chooser. The second is vocabulary: the
/// two-frame pair is retired, and only a scan can see it come
/// back, since a re-added pair type compiles and every arithmetic
/// assertion below still passes beside it.
///
/// `@MainActor` because the quantities are properties of `View`s,
/// which are main-actor isolated: off the main actor the first
/// read traps in the concurrency runtime rather than failing an
/// expectation, and it does so nondeterministically.
@Suite("Layout preview frame")
@MainActor
struct LayoutSchematicScaleTests {
    /// A thumbnail spends its whole canvas on the monitor; the
    /// panel keeps the slice that leaves room for the ghosts.
    /// Asserted through `metrics`, the geometry the drawing reads,
    /// rather than through `screenFraction` alone — a fraction the
    /// metrics stopped consulting would pass a fraction-only test.
    @Test("the tile's monitor is the whole tile")
    func monitorFillsTheTile() {
        let along: CGFloat = 200
        let tile = scrolling(scale: .tile).metrics(along: along)
        #expect(tile.screenStart == 0)
        #expect(tile.screenLen == along)
        #expect(!scrolling(scale: .tile).drawsMonitorOutline)

        let panel = scrolling(scale: .panel).metrics(along: along)
        #expect(panel.screenLen < along)
        #expect(panel.screenStart > 0)
        // Centred: the row continues off BOTH edges, so the two
        // margins have to match or one side's ghosts are cropped.
        #expect(
            panel.screenStart
                == (along - panel.screenLen) / 2
        )
        #expect(scrolling(scale: .panel).drawsMonitorOutline)
    }

    /// The point of the reclaimed canvas: a slot is drawn at the
    /// monitor's scale, so the thumbnail's windows read at the
    /// same size as its siblings' rather than at half. Derived
    /// from the panel's own slot instead of pinned to a number,
    /// so retuning the slot fraction moves both together.
    @Test("a tile slot is drawn at the monitor's scale")
    func slotScalesWithTheMonitor() {
        let along: CGFloat = 400
        let tile = scrolling(scale: .tile).metrics(along: along)
        let panel = scrolling(scale: .panel).metrics(along: along)
        let ratio =
            scrolling(scale: .tile).screenFraction
            / scrolling(scale: .panel).screenFraction
        #expect(abs(tile.slot - panel.slot * ratio) < 0.001)
        #expect(tile.slot > panel.slot)
    }

    /// Every anchor draws one frame of that same monitor, `follow`
    /// included. The anchor moves the focused window inside the
    /// frame and nothing else — a `follow` that resumed branching
    /// away to a second frame would have to leave this row.
    @Test("every anchor rests inside the one frame")
    func everyAnchorRestsInTheFrame() {
        let along: CGFloat = 200
        for anchor in [
            ScrollingParams.Anchor.center, .start, .end, .follow,
        ] {
            let m = scrolling(anchor: anchor, scale: .panel)
                .metrics(along: along)
            #expect(m.focusCenter - m.slot / 2 >= m.screenStart)
            #expect(
                m.focusCenter + m.slot / 2
                    <= m.screenStart + m.screenLen
            )
        }
        // Follow pins the focus nowhere, so it draws the neutral
        // resting frame — the centred one. Asserted against
        // `.center`'s own answer rather than against the midpoint,
        // so the two cannot drift apart silently.
        let follow = scrolling(anchor: .follow, scale: .panel)
            .metrics(along: along)
        let centre = scrolling(anchor: .center, scale: .panel)
            .metrics(along: along)
        #expect(follow.focusCenter == centre.focusCenter)
        #expect(
            scrolling(anchor: .start, scale: .panel)
                .metrics(along: along).focusCenter
                != centre.focusCenter
        )
    }

    /// The retired vocabulary. `SchematicPair` and its arrow had
    /// one consumer, so nothing here is a rule about a type that
    /// still exists — this is what keeps the path retired, the way
    /// every other scan for a withdrawn API does. A pair re-added
    /// tomorrow compiles, draws, and passes every other assertion
    /// in this file.
    @Test("no schematic draws a second frame")
    func theFamilyIsSingleFrame() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts"
            )
        let retired = [
            "SchematicPair",
            "SchematicArrow",
            "ScrollingFollowPair",
            "firstCaption",
            "secondCaption",
        ]
        var checked = 0
        for file in try SourceScan.swiftSources(under: dir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            checked += 1
            for word in retired {
                #expect(
                    !source.contains(word),
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) names "
                            + "\(word) — a layout's second frame "
                            + "denotes two states, not motion; "
                            + "put the fact in the caption"
                    )
                )
            }
        }
        // A rename of the directory yields an empty enumeration
        // rather than throwing, and this scan would then pass for
        // having read nothing.
        #expect(checked > LayoutMode.placementTabs.count)
    }

    private func scrolling(
        anchor: ScrollingParams.Anchor = .center,
        scale: SchematicScale
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: anchor,
            slotSize: .auto,
            placement: .last,
            scale: scale
        )
    }
}
