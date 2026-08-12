import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the Layout Defaults previews open the incoming window
/// (#702).
///
/// Five schematics used to hand-copy `Space.insert(_:placement:)`'s
/// four-arm switch, and `LayoutSchematicCountTests` asserts counts,
/// dimensions and runs — never placement. Mutating one arm left the
/// whole suite green, which is how a Track preview shipped marking
/// the wrong window as focused.
///
/// **These assert the promise a reader takes off the frame, not the
/// call the schematics make.** `SchematicPlacementPromise` states
/// the four arms at the altitude the preview is read at — the `+`
/// opens at the row's start, at its end, or immediately beside the
/// focused tile — and shares no code with the engine or with
/// `SchematicPlacement`. Asserting that each schematic *calls* the
/// helper would pass on one that called it and drew a constant, the
/// failure mode guard-prover already demonstrated against this
/// lane's first count scan.
///
/// `@MainActor` because the derived quantities are properties of
/// `View`s, which are main-actor isolated: off the main actor the
/// first read traps in the concurrency runtime rather than failing
/// an expectation, and nondeterministically — it depends which
/// executor swift-testing lands the test on.
///
/// Scrolling's half lives in `LayoutSchematicScrollingTests`,
/// which sweeps the focus anchors as well as the placements —
/// split off at the file ceiling, and it reads the same
/// `SchematicPlacementPromise` rather than a second copy of it.
@Suite("Layout preview new-window placement")
@MainActor
struct LayoutSchematicPlacementTests {
    /// BSP keys its tiles by window id, so the focus travels with
    /// its window and the whole contract is the array order.
    @Test("BSP opens the window where the engine does")
    func bspPlacement() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = BspSchematic(
                    splitRatioH: 0.5,
                    splitRatioV: 0.5,
                    strategy: .longestSide,
                    placement: placement,
                    windows: count
                )
                let order = schematic.order
                check(
                    order,
                    incoming: schematic.newWindow,
                    focus: schematic.focused,
                    placement: placement,
                    what: "BSP at \(count)"
                )
            }
        }
    }

    /// Stack's array order, across master counts as well as
    /// window counts: at `masterCount: 1` the masters clamp is
    /// inert. This is the flat array only — *which* zone each
    /// window is drawn in is `masterWins` / `stackWins`'
    /// partition of it, which is #707's.
    @Test("Stack opens the window where the engine does")
    func stackPlacement() {
        for placement in placements {
            for masterCount in [1, 3, 10] {
                for count in LayoutSchematic.windowCountRange {
                    let schematic = StackSchematic(
                        masterCount: masterCount,
                        masterRatio: 0.5,
                        overflowStyle: .cascadeOverflow,
                        masterOrientation: .vertical,
                        stackPosition: .right,
                        placement: placement,
                        windows: count
                    )
                    check(
                        schematic.order,
                        incoming: schematic.newWindow,
                        focus: schematic.focused,
                        placement: placement,
                        what: "Stack \(masterCount)m at \(count)"
                    )
                }
            }
        }
    }

    /// Grid fills its cells in array order, so the array *is* the
    /// picture once `GridLayout.dimensions` has chosen them.
    @Test("Grid opens the window where the engine does")
    func gridPlacement() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = GridSchematic(
                    columns: 2,
                    rows: 2,
                    type: .dynamic,
                    fillEmptyCells: false,
                    autoSize: false,
                    splitDirection: .horizontal,
                    placement: placement,
                    windows: count
                )
                check(
                    schematic.ids,
                    incoming: schematic.newID,
                    focus: schematic.focusID,
                    placement: placement,
                    what: "Grid at \(count)"
                )
            }
        }
    }

    /// A new *track* splices into the spec array, so the focused
    /// spec travels with it. Read off `trackSlots` — the strip's
    /// own array — rather than rebuilt here from
    /// `newTrackIndex`: a guard that recomputes the render proves
    /// the number is right and never proves it is used, which is
    /// the failure this suite's docstring names one level up.
    @Test("Track opens a new track where the engine does")
    func trackPlacement() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = track(
                    placement: placement,
                    newWindow: .ownTrack,
                    windows: count
                )
                let drawn = schematic.trackSlots
                check(
                    incoming: drawn.incoming,
                    focus: drawn.focus,
                    slots: 0...schematic.trackCount,
                    placement: placement,
                    what: "Track at \(count)"
                )
            }
        }
    }

    /// The focused track draws a **fixed run of slots**, so it is
    /// the one schematic that must be told the focus moved. Its own
    /// copy of the rule was not: `first` marked the established
    /// window next to the focus, and `before focused` resolved the
    /// `+` and the focus to a single slot, where the `+` won the
    /// ternary and no focused tile was drawn at all (#702).
    @Test("a window joining the focused track pushes the focus")
    func focusedTrackPlacement() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = track(
                    placement: placement,
                    newWindow: .focusedTrack,
                    windows: count
                )
                let drawn = schematic.focusedSlots(nested: true)
                check(
                    incoming: drawn.incoming,
                    focus: drawn.focus,
                    slots: 0...(drawn.count - 1),
                    placement: placement,
                    what: "focused track at \(count)"
                )
                // The two must never resolve to one slot: the
                // render's ternary reaches `.new` first, so a
                // collision erases the focus rather than
                // overlapping it.
                #expect(
                    drawn.incoming != drawn.focus,
                    "focused track at \(count) drew no focus"
                )
                // A run nothing joins keeps its length and its
                // middle focus, and draws no `+` at all — the
                // arm the strip takes for every other track.
                let plain = schematic.focusedSlots(nested: false)
                #expect(plain.count == schematic.focusedRun)
                #expect(plain.incoming < 0)
                #expect(plain.focus == (plain.count - 1) / 2)
                // And the tiles the run actually draws. Reading
                // the tuple alone left the whole #702 symptom
                // reinstatable by a wrong pick downstream of a
                // right tuple — proven green, so this reads the
                // kinds (guard-prover, 2026-08-03).
                check(
                    schematic.focusedTrackKinds(nested: true),
                    placement: placement,
                    what: "focused track at \(count)"
                )
                let plainKinds =
                    schematic
                    .focusedTrackKinds(nested: false)
                #expect(plainKinds.count == schematic.focusedRun)
                #expect(!plainKinds.contains(.new))
                #expect(
                    plainKinds.filter { $0 == .focus }.count == 1
                )
            }
        }
    }

    // MARK: - The promise, and the fixtures

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

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

    /// The tiles a run draws, held to the same promise: exactly
    /// one `+`, exactly one focus — a collision is #702, where
    /// `.new` won the pick and the focused tile vanished — and
    /// the `+` beside the focus or at an end.
    private func check(
        _ kinds: [TrackSchematic.TrackWindow],
        placement: SpawnPlacement,
        what: String
    ) {
        #expect(kinds.filter { $0 == .new }.count == 1)
        #expect(
            kinds.filter { $0 == .focus }.count == 1,
            Comment(rawValue: "\(what): \(kinds) has no focus")
        )
        guard
            let landed = kinds.firstIndex(of: .new),
            let settled = kinds.firstIndex(of: .focus)
        else { return }
        check(
            incoming: landed,
            focus: settled,
            slots: 0...(kinds.count - 1),
            placement: placement,
            what: "\(what) tiles"
        )
    }

    /// The id-keyed schematics: find both windows in the array the
    /// schematic built, then hold it to the same promise.
    private func check<T: Equatable>(
        _ order: [T],
        incoming: T,
        focus: T,
        placement: SpawnPlacement,
        what: String
    ) {
        guard
            let landed = order.firstIndex(of: incoming),
            let settled = order.firstIndex(of: focus)
        else {
            Issue.record("\(what): + or focus missing from \(order)")
            return
        }
        check(
            incoming: landed,
            focus: settled,
            slots: 0...(order.count - 1),
            placement: placement,
            what: what
        )
    }

    private func track(
        placement: SpawnPlacement,
        newWindow: TrackParams.NewWindowTrack,
        windows: Int
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: .cascadeAll,
            newWindow: newWindow,
            placement: placement,
            limit: 3,
            autoTracks: false,
            windows: windows
        )
    }
}
