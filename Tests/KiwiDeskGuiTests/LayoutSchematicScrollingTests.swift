import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the Scrolling preview opens the incoming window, across
/// every focus anchor (#702, #753).
///
/// Split from `LayoutSchematicPlacementTests` at the file ceiling,
/// and the anchor sweep is why it earned the room: since #753
/// `follow` draws the same single frame as the other three, where
/// before it branched away to a two-frame pair that carried no `+`
/// at all. An anchor that stops asking `SchematicPlacement.splice`
/// — or branches away again — reds here.
///
/// **The promise below is stated independently of the engine and
/// of `SchematicPlacement`**, the way its parent suite states it:
/// asserting that the schematic *calls* the helper would pass on
/// one that called it and drew a constant.
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
    /// landing rather than beside it.
    @Test("Scrolling opens the window where the engine does")
    func scrollingPlacement() {
        for anchor in anchors {
            for placement in placements {
                for count in LayoutSchematic.windowCountRange {
                    let schematic = ScrollingSchematic(
                        orientation: .horizontal,
                        anchor: anchor,
                        slotSize: .auto,
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
                }
            }
        }
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
                    orientation: .horizontal,
                    placement: placement,
                    windows: count
                ).row
                #expect(across.slots == along.slots)
                #expect(across.incoming == along.incoming)
            }
        }
    }

    // MARK: - The promise, and the fixtures

    private let anchors: [ScrollingParams.Anchor] = [
        .center, .start, .end, .follow,
    ]

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// What the four arms promise a reader, stated at the altitude
    /// the preview is read at. `focus` is where the focused tile
    /// **ends up**: a landing at or before it moves it one slot
    /// along, and a preview that forgets that is #702.
    private func expectedSlot(
        _ placement: SpawnPlacement,
        focus: Int,
        slots: ClosedRange<Int>
    ) -> Int {
        switch placement {
        case .first: return slots.lowerBound
        case .last: return slots.upperBound
        case .beforeFocused: return focus - 1
        case .afterFocused: return focus + 1
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
                == expectedSlot(
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
        orientation: ScrollingParams.Orientation,
        placement: SpawnPlacement,
        windows: Int
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: orientation,
            anchor: .center,
            slotSize: .auto,
            placement: placement,
            windows: windows
        )
    }
}
