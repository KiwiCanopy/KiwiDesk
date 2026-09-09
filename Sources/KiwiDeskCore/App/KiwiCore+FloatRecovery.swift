import CoreGraphics

/// Re-centres a float whose remembered position is gone (#1352).
///
/// The stash restores a parked float from the capture taken at
/// its first park, and that capture can be lost while the
/// window still sits at the corner: a late park echo read as a
/// user move, a Desktop switch sweeping the departed window's
/// entry, a relaunch replaying the parked snapshot, a profile
/// switch turning a tiled space floating. The stash refuses to
/// capture a corner as an original, so such a window arrives on
/// its shown space with no capture and nothing to place it.
/// This is the net that places it — once, and where
/// `floatBounds` says a float may sit.
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
                    // A sticky window rides the carry (#1145),
                    // never the stash.
                    window.stickyScope == .none,
                    // EFFECTIVE float, never the flag (#1178).
                    EffectiveFloat.applies(
                        isFloating: window.isFloating,
                        mode: workspace.mode
                    ),
                    tiler.stashOriginal(id) == nil,
                    isStranded(window.frame),
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

    /// Whether a frame sits at some screen's stash corner, read
    /// over the topology seam the stash parks through (#878) so
    /// the two cannot disagree about the screens.
    private func isStranded(_ frame: CGRect) -> Bool {
        tiler.allScreenBounds().contains {
            TilingEngine.looksStashed(frame, in: $0)
        }
    }

    /// The session snapshot the crash and sleep legs write:
    /// state, with a parked float's CAPTURE in place of its
    /// state frame. The state frame of a parked float is the
    /// corner, and a restore replaying it verbatim put the
    /// window back there with nothing left to undo it.
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
