import CoreGraphics

/// Re-centres a float whose remembered position is gone (#1352):
/// the stash refuses to capture a corner as an original, so a
/// float found at one with no capture has nothing to place it
/// but this net.
extension KiwiCore {
    /// Seeds a centred capture for every stranded float on a
    /// shown space, ahead of the retile whose restore pass
    /// delivers it. A pure decision: the delivery, its echo
    /// bookkeeping and the bar fit stay the restore's and the
    /// clamp's.
    func recoverStrandedFloats() {
        for space in state.workspaces.visibleSpaces {
            guard let workspace = state.workspaces[space]
            else { continue }
            for id in workspace.windows {
                guard let window = state.windows[id],
                    !window.isFullscreen,
                    id != tiler.dragExemptWindow,
                    // Never parked ⇒ never stranded: the same
                    // exemption the park decides on (#445).
                    !state.stickyExemptFromStash(
                        window,
                        onSpace: space
                    ),
                    // EFFECTIVE float, never the flag (#1178).
                    EffectiveFloat.applies(
                        isFloating: window.isFloating,
                        mode: workspace.mode
                    ),
                    tiler.stashOriginal(id) == nil,
                    tiler.looksStashed(window.frame),
                    let region = floatBounds(on: space)
                else { continue }
                let centred = FloatRecovery.centred(
                    window.frame.size,
                    in: region
                )
                tiler.seedStash(id, frame: centred)
                onLog(
                    "float \(id) stranded at the stash corner "
                        + "on space \(space); re-centring"
                )
            }
        }
    }

    /// The session snapshot the crash and sleep legs write —
    /// every `captureState` consumer takes this, never
    /// `state.snapshot()`: state, with a parked float's CAPTURE
    /// in place of its state frame. The state frame of a parked
    /// float is the corner, and a restore replaying it verbatim
    /// put the window back there with nothing left to undo it.
    func sessionSnapshot() -> StateSnapshot {
        let snapshot = state.snapshot()
        return StateSnapshot(
            windows: snapshot.windows.map { record in
                guard
                    let original = tiler.stashOriginal(
                        record.windowID
                    )
                else { return record }
                return StateSnapshot.WindowRecord(
                    id: record.windowID,
                    frame: original
                )
            },
            spaces: snapshot.spaces,
            activeSpace: snapshot.activeSpace
        )
    }
}

/// The centring arithmetic, pure so a fixture can pin it.
public enum FloatRecovery {
    /// `size` centred in `region`, shrunk to fit where it is
    /// larger: a centred frame that overhangs the region is not
    /// usable either, and the retile fit would shrink it anyway.
    public static func centred(
        _ size: CGSize,
        in region: CGRect
    ) -> CGRect {
        let width = min(size.width, region.width)
        let height = min(size.height, region.height)
        return CGRect(
            x: region.midX - width / 2,
            y: region.midY - height / 2,
            width: width,
            height: height
        )
    }
}
