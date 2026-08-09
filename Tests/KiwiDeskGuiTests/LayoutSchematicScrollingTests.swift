import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Scrolling preview across every focus anchor (#702, #753).
///
/// Split from `LayoutSchematicPlacementTests` at the file ceiling,
/// and the anchor is why it earned the room: since #753 `follow`
/// draws the same single frame as the other three, where before it
/// branched away to a two-frame pair that carried no `+` at all.
///
/// **The anchor dimension has to reach something the anchor moves,
/// or the sweep is four identical iterations.** `row` reads only
/// the count and the placement, so a first cut of this file looped
/// the anchors around it and proved nothing about any of them —
/// a re-added `if anchor == .follow` in `body` left `row`
/// untouched and the suite green. So every anchor iteration also
/// reads `metrics`, whose `focusCenter` is the one thing the
/// anchor decides.
///
/// **The placement promise is stated independently of the engine
/// and of `SchematicPlacement`** — asserting that the schematic
/// *calls* the helper would pass on one that called it and drew a
/// constant — and it is the shared `SchematicPlacementPromise`
/// rather than a second copy, because a copy of the rule under
/// guard leaves one suite green on the retired rule.
///
/// The words beside the frame are `LayoutSchematicCaptionTests`',
/// split off before this file reached the ceiling.
///
/// `@MainActor` because the derived quantities are properties of
/// `View`s, which are main-actor isolated: off the main actor the
/// first read traps in the concurrency runtime rather than failing
/// an expectation, and nondeterministically.
@Suite("Layout preview scrolling placement")
@MainActor
struct LayoutSchematicScrollingTests {
    /// Scrolling pins the focus to slot 0, so a splice that pushes
    /// the focus shifts the *row* instead. Both come off the one
    /// splice, which is why the bounds are asserted with the
    /// landing rather than beside it — and the anchor's own answer
    /// is read in the same breath, off the metrics the strip lays
    /// out from.
    @Test("Scrolling opens the window where the engine does")
    func scrollingPlacement() {
        let along: CGFloat = 400
        for anchor in ScrollingParams.Anchor.allCases {
            for placement in placements {
                for count in LayoutSchematic.windowCountRange {
                    let schematic = scrolling(
                        anchor: anchor,
                        placement: placement,
                        windows: count
                    )
                    let row = schematic.row
                    #expect(row.slots.count == count)
                    #expect(row.slots.contains(0))
                    check(
                        incoming: row.incoming,
                        focus: 0,
                        slots: row.slots,
                        placement: placement,
                        what: "Scrolling \(anchor) at \(count)"
                    )
                    // The anchor half: the row the `+` sits in is
                    // the row the drawing lays out, and the focus
                    // it is measured from is where this anchor
                    // puts it.
                    let m = schematic.metrics(along: along)
                    #expect(m.newIdx == row.incoming)
                    #expect(m.low == row.slots.lowerBound)
                    #expect(m.high == row.slots.upperBound)
                    #expect(
                        m.focusCenter == restingCenter(anchor, m),
                        Comment(
                            rawValue:
                                "\(anchor) rested at "
                                + "\(m.focusCenter)"
                        )
                    )
                }
            }
        }
    }

    /// Every anchor draws one frame of one monitor, `follow`
    /// included: it moves the focused window inside the frame and
    /// nothing else. Scrolling-only arithmetic, so it lives here
    /// rather than in the family-scoped frame suite.
    @Test("every anchor rests inside the one frame")
    func everyAnchorRestsInTheFrame() {
        let along: CGFloat = 200
        for anchor in ScrollingParams.Anchor.allCases {
            let m = scrolling(anchor: anchor).metrics(along: along)
            #expect(m.focusCenter - m.slot / 2 >= m.screenStart)
            #expect(
                m.focusCenter + m.slot / 2
                    <= m.screenStart + m.screenLen
            )
        }
        // Follow pins the focus nowhere, so it draws the neutral
        // resting frame — the centred one. Asserted against
        // `.center`'s own answer rather than against the midpoint,
        // so the two cannot drift apart silently. The collapse is
        // deliberate and argued in `docs/design-decisions.md`; the
        // caption is what tells the pair apart, which the test
        // below holds.
        let follow = scrolling(anchor: .follow)
            .metrics(along: along)
        let centre = scrolling(anchor: .center)
            .metrics(along: along)
        #expect(follow.focusCenter == centre.focusCenter)
        #expect(
            scrolling(anchor: .start).metrics(along: along)
                .focusCenter != centre.focusCenter
        )
    }

    /// The vertical orientation reads the same row — the anchor
    /// and the axis are independent, and folding them was how the
    /// `+` could have been right on one axis only.
    @Test("the row is the same on either axis")
    func orientationDoesNotMoveTheRow() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let across = scrolling(
                    orientation: .vertical,
                    placement: placement,
                    windows: count
                ).row
                let along = scrolling(
                    placement: placement,
                    windows: count
                ).row
                #expect(across.slots == along.slots)
                #expect(across.incoming == along.incoming)
            }
        }
    }

    // MARK: - The promise, and the fixtures

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// Where each anchor rests the focused window, stated
    /// independently of the schematic's own switch.
    private func restingCenter(
        _ anchor: ScrollingParams.Anchor,
        _ m: ScrollingSchematic.Metrics
    ) -> CGFloat {
        switch anchor {
        // Follow rests centred: it pins the focus nowhere, so the
        // neutral frame is the only resting position it can claim.
        case .center, .follow:
            return m.screenStart + m.screenLen / 2
        case .start: return m.screenStart + m.slot / 2
        case .end:
            return m.screenStart + m.screenLen - m.slot / 2
        }
    }

    private func check(
        incoming: Int,
        focus: Int,
        slots: ClosedRange<Int>,
        placement: SpawnPlacement,
        what: String
    ) {
        #expect(
            incoming
                == SchematicPlacementPromise.expectedSlot(
                    placement,
                    focus: focus,
                    slots: slots
                ),
            Comment(
                rawValue:
                    "\(what), \(placement.rawValue): + at "
                    + "\(incoming), focus at \(focus), row "
                    + "\(slots)"
            )
        )
        #expect(slots.contains(incoming))
        #expect(slots.contains(focus))
    }

    private func scrolling(
        orientation: ScrollingParams.Orientation = .horizontal,
        anchor: ScrollingParams.Anchor = .center,
        placement: SpawnPlacement = .last,
        windows: Int = LayoutSchematic.defaultWindowCount
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: orientation,
            anchor: anchor,
            slotSize: .auto,
            placement: placement,
            windows: windows
        )
    }
}
