import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Track mode has a spawn engine of its own.
///
/// `TrackSchematic` asks `SchematicPlacement.splice`, which drives
/// `Space.insert(_:placement:)` — but a window opening in a track
/// space actually goes through `Space.insertIntoTrack` (#128,
/// #188). Its two positioning arms happen to be the same splice
/// rule applied to a different array: `insertOwnTrack` positions
/// among *tracks*, `joinTrack` among the focused track's own
/// *windows*. "Happens to be" is the part worth pinning — so this
/// runs the real engine over a fixture shaped like the preview and
/// requires the same answer, rather than leaving the agreement to
/// arithmetic somebody re-derives (architect review, 2026-08-03).
///
/// **Scope.** Position only, still — but for a narrower reason
/// than when this was written. #708 taught the preview
/// fill-then-spill, so the old caveat ("the preview models
/// neither `spillCapacity` nor `trackCap`") is retired: it now
/// models both, through `TrackLayout.spillsToNewTrack`, which is
/// the engine's own predicate rather than a copy.
///
/// The fixtures below still disable the spill (`spillCapacity`
/// nil) because this suite's subject is the POSITIONING arms —
/// where among tracks, and where among a track's windows. The
/// fold's agreement with the engine is
/// `LayoutSchematicTrackFoldTests`'; keeping the two apart is
/// what lets each fail for one reason.
@Suite("Track preview vs the track spawn engine")
@MainActor
struct LayoutSchematicTrackEngineTests {
    /// One window per track, so a track index *is* an array index
    /// and the engine's answer needs no translation.
    @Test("a new track lands where insertIntoTrack puts it")
    func ownTrackParity() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = track(
                    placement: placement,
                    newWindow: .ownTrack,
                    windows: count
                )
                let drawn = schematic.trackSlots
                let engine = engineSlots(
                    tracks: schematic.trackCount,
                    perTrack: 1,
                    // The schematic's OWN focus index, not a
                    // re-derived `trackCount / 2`. That literal
                    // was the drawing convention this preview
                    // used before it modelled fill-then-spill;
                    // once the fold decided the focus, a fixture
                    // repeating the old rule pinned the
                    // convention instead of the parity it claims
                    // (#708 follow-up, 2026-08-16).
                    focusTrack: schematic.focusIdx,
                    rule: .ownTrack,
                    placement: placement
                )
                #expect(
                    drawn.incoming == engine.incoming,
                    Comment(
                        rawValue:
                            "own track at \(count), "
                            + "\(placement.rawValue): preview "
                            + "\(drawn.incoming), engine "
                            + "\(engine.incoming)"
                    )
                )
                #expect(drawn.focus == engine.focus)
            }
        }
    }

    /// One track holding the whole run, so an array index is a
    /// slot in the focused track.
    @Test("a joining window lands where insertIntoTrack puts it")
    func joinTrackParity() {
        for placement in placements {
            for count in LayoutSchematic.windowCountRange {
                let schematic = track(
                    placement: placement,
                    newWindow: .focusedTrack,
                    windows: count
                )
                let run = schematic.focusedRun
                let drawn = schematic.focusedSlots(nested: true)
                let engine = engineSlots(
                    tracks: 1,
                    perTrack: run,
                    focusTrack: 0,
                    rule: .focusedTrack,
                    placement: placement
                )
                #expect(
                    drawn.incoming == engine.incoming,
                    Comment(
                        rawValue:
                            "joining track at \(count), "
                            + "\(placement.rawValue): preview "
                            + "\(drawn.incoming), engine "
                            + "\(engine.incoming)"
                    )
                )
                #expect(drawn.focus == engine.focus)
                #expect(drawn.count == run + 1)
            }
        }
    }

    // MARK: - Fixtures

    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// Runs the real `Space.insertIntoTrack` over `tracks` tracks
    /// of `perTrack` windows each, focused in the middle of
    /// `focusTrack`, and reports where the incoming window and the
    /// focused window ended up in the flat array.
    ///
    /// With one window per track the flat index is the track
    /// index; with a single track it is the slot in that track's
    /// run. Those are the two shapes the preview draws, which is
    /// why the fixture takes both rather than a general partition.
    private func engineSlots(
        tracks: Int,
        perTrack: Int,
        focusTrack: Int,
        rule: TrackParams.NewWindowTrack,
        placement: SpawnPlacement
    ) -> (incoming: Int, focus: Int) {
        let total = tracks * perTrack
        let windows = (0..<total).map { WindowID(UInt32($0)) }
        let heads = stride(from: 0, to: total, by: perTrack)
            .map { windows[$0] }
        let focused =
            windows[focusTrack * perTrack + (perTrack - 1) / 2]
        var space = Space(
            id: "schematic",
            mode: .track,
            windows: windows,
            focused: focused,
            trackBreaks: Set(heads)
        )
        let incoming = WindowID(UInt32(total))
        space.insertIntoTrack(
            incoming,
            rule: rule,
            position: placement,
            isTiled: { _ in true }
        )
        return (
            space.windows.firstIndex(of: incoming) ?? -1,
            space.windows.firstIndex(of: focused) ?? -1
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
