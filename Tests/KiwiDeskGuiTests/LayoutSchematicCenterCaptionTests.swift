import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Center anchor's caption (#1382): a centred row meets both
/// screen edges, so its words carry the cut-windows clause exactly
/// where the frame draws a window the edge cuts — one key per
/// sentence, the clause never pointing past the drawing. Split
/// from `LayoutSchematicCaptionTests` at that file's ceiling; the
/// same locale caveat holds — every claim compares two rendered
/// strings from one catalog.
///
/// `@MainActor`: the prose producers are `View` members.
@Suite("Layout preview captions ▸ Center")
@MainActor
struct LayoutSchematicCenterCaptionTests {
    /// The clause's predicate is width-free (judged at the
    /// panel's one fixed length) while the pane is not, so it is
    /// held to the drawing at every length a pane can take — the
    /// panel is `SettingsTheme.panelWidth` wide, so the band
    /// starts where the 14 pt slot floor stops biting; below it a
    /// floored slot is a frame no pane draws.
    @Test("the cut clause is claimed only where the frame cuts")
    func theCutClauseMatchesTheDrawing() {
        var claimed = 0
        var withheld = 0
        #expect(SettingsTheme.panelWidth >= widths[0])
        for orientation in ScrollingParams.Orientation.allCases {
            for size in slotSizes {
                for count in LayoutSchematic.windowCountRange {
                    let s = scrolling(
                        orientation: orientation,
                        slotSize: size,
                        windows: count
                    )
                    if s.drawsCutWindows {
                        claimed += 1
                    } else {
                        withheld += 1
                    }
                    for along in widths {
                        #expect(
                            s.cutsWindow(along: along)
                                == s.drawsCutWindows,
                            Comment(
                                rawValue:
                                    "\(orientation)/\(size) at "
                                    + "\(count), \(along) pt"
                            )
                        )
                    }
                }
            }
        }
        #expect(claimed > 0)
        #expect(withheld > 0)
    }

    /// The engine's arithmetic, drawn: a third tiles the screen
    /// with the focused window in the middle and one whole
    /// neighbour each side, so nothing is cut; a half puts the
    /// neighbours across the edges.
    @Test("an odd count tiles whole, an even count cuts")
    func parity() {
        #expect(!scrolling(slotSize: .fraction(1.0 / 3)).drawsCutWindows)
        #expect(scrolling(slotSize: .fraction(0.5)).drawsCutWindows)
        #expect(scrolling(slotSize: .fraction(0.25)).drawsCutWindows)
        #expect(!scrolling(slotSize: .fraction(0.2)).drawsCutWindows)
        // The shipped default peeks a sliver of each neighbour.
        #expect(scrolling(slotSize: .auto).drawsCutWindows)
        // A lone window is never cut.
        #expect(!scrolling(slotSize: .auto, windows: 1).drawsCutWindows)
    }

    /// The words follow the predicate: the two Center sentences
    /// differ exactly by the clause, and neither is the anchored
    /// sentence Left and Right keep.
    @Test("the caption and the spoken label carry the clause")
    func theClauseIsRendered() {
        let cut = scrolling(slotSize: .fraction(0.5))
        let whole = scrolling(slotSize: .fraction(1.0 / 3))
        #expect(cut.drawsCutWindows)
        #expect(!whole.drawsCutWindows)
        #expect(cut.caption != whole.caption)
        #expect(cut.axLabel != whole.axLabel)
        #expect(cut.caption.count > whole.caption.count)
        #expect(cut.axLabel.count > whole.axLabel.count)
        let left = scrolling(anchor: .start, slotSize: .fraction(0.5))
        #expect(left.caption != cut.caption)
        #expect(left.caption != whole.caption)
        // The insertion clause still lands last, or not at all.
        let beside = scrolling(
            placement: .afterFocused,
            slotSize: .fraction(0.5)
        )
        #expect(beside.drawsInsertionMark)
        #expect(beside.caption.hasSuffix(beside.insertionClause))
        #expect(cut.insertionClause.isEmpty)
        #expect(!cut.caption.hasSuffix(" "))
        #expect(!whole.caption.hasSuffix(" "))
    }

    // MARK: - Fixtures

    private let slotSizes: [ScrollSize] = [
        .auto, .points(300), .points(900),
        .fraction(0.2), .fraction(0.25), .fraction(1.0 / 3),
        .fraction(0.5), .fraction(0.6), .fraction(0.95),
    ]

    private let widths: [CGFloat] = [228, 240, 360, 400, 900, 1600]

    private func scrolling(
        orientation: ScrollingParams.Orientation = .horizontal,
        anchor: ScrollingParams.Anchor = .center,
        placement: SpawnPlacement = .last,
        slotSize: ScrollSize = .auto,
        windows: Int = LayoutSchematic.defaultWindowCount
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: orientation,
            anchor: anchor,
            slotSize: slotSize,
            placement: placement,
            windows: windows,
            scale: .panel
        )
    }
}
