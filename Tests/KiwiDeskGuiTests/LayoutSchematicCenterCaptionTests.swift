import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Center anchor's words (#1382): a centred row meets both
/// screen edges, so the caption and the spoken label carry the
/// cut-windows clause exactly where the frame drawn at the length
/// the strip laid out at cuts a window — never at a length no
/// scale draws, since the tile speaks the same label. Two claims,
/// held apart: the sweep holds the WORDS to the predicate at
/// every length (a fixed-length judgement re-introduced anywhere
/// on the way reds), and `parity` is the one oracle holding the
/// predicate to the DRAWING, at the panel's length; that the view
/// judges on the length it laid out at rests on the needles in
/// `judgedLength`. Split from `LayoutSchematicCaptionTests` at
/// that file's ceiling; the same locale caveat holds — every claim
/// compares two rendered strings from one catalog.
///
/// `@MainActor`: the prose producers are `View` members.
@Suite("Layout preview captions ▸ Center")
@MainActor
struct LayoutSchematicCenterCaptionTests {
    /// The words at any length are the sentence the predicate at
    /// that length picks — over both scales, both orientations,
    /// every slot size and count, at every length a pane can lay
    /// the strip out at, the drawn ones included.
    @Test("the words follow the predicate at every drawn length")
    func theWordsFollowTheFrame() {
        var cut = 0
        var whole = 0
        for scale in SchematicScale.allCases {
            for orientation in ScrollingParams.Orientation.allCases {
                for size in slotSizes {
                    for count in LayoutSchematic.windowCountRange {
                        let s = scrolling(
                            orientation: orientation,
                            slotSize: size,
                            windows: count,
                            scale: scale
                        )
                        for along in lengths + [s.fixedAlong] {
                            let cuts = s.cutsWindow(along: along)
                            if cuts { cut += 1 } else { whole += 1 }
                            expectWords(s, along: along, cut: cuts)
                        }
                    }
                }
            }
        }
        #expect(cut > 0)
        #expect(whole > 0)
    }

    private func expectWords(
        _ s: ScrollingSchematic,
        along: CGFloat,
        cut: Bool
    ) {
        let what = Comment(rawValue: "\(s.scale) at \(along) pt")
        #expect(
            s.caption(along: along)
                == ScrollingSchematic.centerSentence(
                    cut: cut,
                    insertion: s.insertionClause
                )
                .trimmingCharacters(in: .whitespaces),
            what
        )
        #expect(
            s.axLabel(along: along)
                == ScrollingSchematic.centerAxLabel(cut: cut),
            what
        )
    }

    /// The view speaks the length it drew; before it has drawn,
    /// its scale's own fixed length — the canvas less the inset
    /// band, which is what the tile is and what the panel is on
    /// its fixed axis.
    @Test("the view is judged on the drawn length, else its own")
    func judgedLength() throws {
        let tileH = scrolling(scale: .tile)
        let tileV = scrolling(orientation: .vertical, scale: .tile)
        let inset = 2 * LayoutSchematic.inset
        let tileWidth = try #require(SchematicScale.tile.width)
        #expect(tileH.fixedAlong == tileWidth - inset)
        #expect(tileV.fixedAlong == SchematicScale.tile.height - inset)
        let panelV = scrolling(orientation: .vertical)
        #expect(panelV.fixedAlong == SchematicScale.panel.height - inset)
        // A horizontal panel has no fixed width: the height stands
        // in until the strip has drawn.
        #expect(scrolling().fixedAlong == panelV.fixedAlong)
        #expect(tileH.judgedAlong == tileH.fixedAlong)
        #expect(tileH.caption == tileH.caption(along: tileH.fixedAlong))
        #expect(tileH.axLabel == tileH.axLabel(along: tileH.fixedAlong))
        // The strip records what it laid out at, once per layout.
        let source = try SourceScan.stripComments(
            String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Layouts/"
                            + "ScrollingSchematic.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(source.occurrences(of: "drawnAlong = along") == 1)
        #expect(source.occurrences(of: "drawnAlong = now") == 1)
        #expect(source.occurrences(of: "drawnAlong ?? fixedAlong") == 1)
        // And the canvas reads the words at that length, both
        // channels — a fixture never draws, so only a needle sees
        // the read.
        let words = try SourceScan.stripComments(
            String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Layouts/"
                            + "ScrollingSchematic+Caption.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(words.occurrences(of: "caption(along: judgedAlong)") == 1)
        #expect(words.occurrences(of: "axLabel(along: judgedAlong)") == 1)
    }

    /// The engine's arithmetic, drawn at the panel's length: a
    /// third tiles the screen with the focused window in the
    /// middle and one whole neighbour each side, so nothing is
    /// cut; a half puts the neighbours across the edges. The
    /// quantum is held by this band — zero reds on the tiling
    /// cases, twenty on the quarter's sliver — not by its value;
    /// the lone case holds by geometry, no slot exceeding the
    /// screen.
    @Test("an odd count tiles whole, an even count cuts")
    func parity() {
        let along = scrolling(orientation: .vertical).fixedAlong
        func cuts(_ size: ScrollSize, windows: Int = 5) -> Bool {
            scrolling(orientation: .vertical, slotSize: size, windows: windows)
                .drawsCutWindows(along: along)
        }
        #expect(!cuts(.fraction(1.0 / 3)))
        #expect(cuts(.fraction(0.5)))
        #expect(cuts(.fraction(0.25)))
        #expect(!cuts(.fraction(0.2)))
        // The shipped default peeks a sliver of each neighbour.
        #expect(cuts(.auto))
        // A lone window is never cut.
        #expect(!cuts(.auto, windows: 1))
    }

    /// The two Center sentences differ exactly by the clause, and
    /// neither is the anchored sentence Left and Right keep; the
    /// insertion clause still lands last, or not at all.
    @Test("the sentences are distinct and end cleanly")
    func sentences() {
        let cut = ScrollingSchematic.centerSentence(
            cut: true,
            insertion: ""
        )
        let whole = ScrollingSchematic.centerSentence(
            cut: false,
            insertion: ""
        )
        #expect(cut != whole)
        #expect(cut.count > whole.count)
        #expect(
            ScrollingSchematic.centerAxLabel(cut: true).count
                > ScrollingSchematic.centerAxLabel(cut: false).count
        )
        let left = scrolling(anchor: .start, slotSize: .fraction(0.5))
        let trimmed = whole.trimmingCharacters(in: .whitespaces)
        #expect(!left.caption.contains(trimmed))
        // And Center is routed to its own sentence, not Left's.
        let center = scrolling(slotSize: .fraction(0.5))
        #expect(center.caption != left.caption)
        #expect(center.axLabel != left.axLabel)
        let beside = scrolling(
            placement: .afterFocused,
            slotSize: .fraction(0.5)
        )
        #expect(beside.drawsInsertionMark)
        #expect(beside.caption.hasSuffix(beside.insertionClause))
        let plain = scrolling(slotSize: .fraction(0.5))
        #expect(!plain.caption.hasSuffix(" "))
    }

    // MARK: - Fixtures

    private let slotSizes: [ScrollSize] = [
        .auto, .points(300), .points(500), .points(900),
        .fraction(0.15), .fraction(0.2), .fraction(0.25),
        .fraction(0.32), .fraction(1.0 / 3), .fraction(0.5),
        .fraction(0.6), .fraction(0.95),
    ]

    /// Lengths the strip has been laid out at: the tile's two,
    /// the panel's vertical, the panel's drawn horizontal
    /// (`SettingsTheme.panelWidth` less its chrome, host-dependent
    /// by a few points, so a band around it), and wider panes.
    private let lengths: [CGFloat] = [
        72, 120, 228, 300, 312, 336, 348, 360, 900, 1600,
    ]

    private func scrolling(
        orientation: ScrollingParams.Orientation = .horizontal,
        anchor: ScrollingParams.Anchor = .center,
        placement: SpawnPlacement = .last,
        slotSize: ScrollSize = .auto,
        windows: Int = LayoutSchematic.defaultWindowCount,
        scale: SchematicScale = .panel
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: orientation,
            anchor: anchor,
            slotSize: slotSize,
            placement: placement,
            windows: windows,
            scale: scale
        )
    }
}
