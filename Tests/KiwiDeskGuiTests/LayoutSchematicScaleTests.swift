import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a schematic's frame is allowed to be (#753).
///
/// Three halves of one decision, and they fail apart. The first is
/// arithmetic: Scrolling reserves canvas for its off-monitor
/// ghosts, and reserving it at `.tile` drew the monitor at half
/// the size of every sibling's outline — the thumbnail that read
/// as broken in the layout chooser. The second is vocabulary: the
/// two-frame pair is retired, and only a scan can see it come
/// back, since a re-added pair type compiles and every arithmetic
/// assertion below still passes beside it. The third is that the
/// resolved answers are actually DRAWN: a property is deletable at
/// its branch with every assertion above it green, which is the
/// Monitors lesson this lane inherits.
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
    /// same size as its siblings' rather than at half.
    ///
    /// Read off the panel's own monitor rather than as a quotient
    /// of the two `screenFraction`s. That quotient is the same two
    /// numbers the slot is built from, so it cancels: `tile.slot
    /// == panel.slot * ratio` is an identity for ANY pair of
    /// fractions above the 14 pt floor, a scale-blind pair
    /// included, and it passed while proving nothing.
    @Test("a tile slot is drawn at the monitor's scale")
    func slotScalesWithTheMonitor() {
        let along: CGFloat = 400
        let tile = scrolling(scale: .tile).metrics(along: along)
        let panel = scrolling(scale: .panel).metrics(along: along)
        // The slot is a fraction of the MONITOR. At `.tile` the
        // monitor is the whole canvas, so the same fraction of the
        // whole canvas is what the thumbnail must draw — which is
        // false for every tile fraction but 1.
        let ofTheMonitor = panel.slot / panel.screenLen
        #expect(abs(tile.slot - along * ofTheMonitor) < 0.001)
        #expect(tile.slot > panel.slot)
        // And the margin the panel pays for that fraction still
        // reads: a ghost is a window-sized rectangle, so a margin
        // much narrower than a slot shows a sliver rather than a
        // window and says nothing about the row continuing.
        #expect(panel.screenStart > panel.slot * 0.6)
    }

    /// The two resolved answers are drawn, not merely resolved.
    ///
    /// Both are `if`s inside a `body`, and a surfacing branch
    /// leaves nothing behind for a property test to find: deleting
    /// either one keeps every assertion above green
    /// (`MonitorsGateWiringTests`' `surfacingBranchesAreDrawn` is
    /// the worked example this copies). Keyed on the branch WITH
    /// its body, over comment-stripped, whitespace-free source, so
    /// a comment quoting the call cannot stand in for it and the
    /// formatter may rewrap it freely.
    @Test("the frame's decisions reach the drawing")
    func theFrameDecisionsAreDrawn() throws {
        let draws: [String: [String]] = [
            "ScrollingSchematic.swift": [
                // The monitor's own outline, drawn only where the
                // monitor is a slice of the canvas.
                "ifdrawsMonitorOutline{outline(m,cross:cross)}",
                // A slot the canvas cannot reach draws nothing.
                // Without it the clip leaves a few points of a
                // tile inside `LayoutSchematic.inset`'s band —
                // most visibly a grey ghost at a thumbnail's edge,
                // where every off-monitor slot is one of these.
                "if!onCanvas(i,m,along:along){EmptyView()}",
                // The ghost itself, which only the panel's margin
                // has room for and which the skip above is what
                // keeps off a thumbnail.
                "}else{SchematicGhostOverflow()}",
            ],
            "ScrollingSchematic+Caption.swift": [
                // The `+` clause is withheld, not merely computed:
                // a caption pointing at a mark the row put off the
                // canvas is the contradiction this gate exists to
                // stop.
                "guarddrawsInsertionMarkelse{return\"\"}"
            ],
        ]
        for (name, needles) in draws {
            let source = try squashed(name)
            for needle in needles {
                #expect(
                    source.contains(needle),
                    Comment(
                        rawValue:
                            "\(name) no longer draws off "
                            + "`\(needle)` — a resolved answer "
                            + "nothing renders is deletable with "
                            + "the whole suite green"
                    )
                )
            }
        }
    }

    /// The retired vocabulary. `SchematicPair` and its arrow had
    /// one consumer, so nothing here is a rule about a type that
    /// still exists — this is what keeps the path retired, the way
    /// every other scan for a withdrawn API does. A pair re-added
    /// tomorrow compiles, draws, and passes every other assertion
    /// in this file.
    ///
    /// Scoped to the whole Settings tree rather than to the
    /// Layouts directory: `Common/` is where gui.md sends a
    /// primitive shared across component areas, so a re-added
    /// `SchematicPair` would most naturally land exactly where a
    /// Layouts-only scan cannot see it.
    @Test("no schematic draws a second frame")
    func theFamilyIsSingleFrame() throws {
        let retired = [
            "SchematicPair",
            "SchematicArrow",
            "ScrollingFollowPair",
            "firstCaption",
            "secondCaption",
        ]
        var checked = 0
        for file in try SourceScan.swiftSources(under: settingsDir) {
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
        // having read nothing. The Settings tree is far larger
        // than the schematics, so the floor is generous and still
        // catches a walk that read nothing.
        #expect(checked > LayoutMode.placementTabs.count)
    }

    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Whitespace-free source, so a needle survives the formatter
    /// wrapping a call across lines.
    private func squashed(_ name: String) throws -> String {
        let file =
            settingsDir
            .appendingPathComponent("Components/Layouts")
            .appendingPathComponent(name)
        return SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    private func scrolling(
        scale: SchematicScale
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: .center,
            slotSize: .auto,
            placement: .last,
            scale: scale
        )
    }
}
