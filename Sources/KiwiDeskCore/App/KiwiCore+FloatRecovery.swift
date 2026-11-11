import CoreGraphics

/// Re-centres a float whose remembered position is gone (#1352):
/// the stash refuses to capture a corner as an original, so a
/// float found at one with no capture has nothing to place it
/// but this net.
extension KiwiCore {
    /// Seeds a centred capture for every stranded float on a
    /// shown space, ahead of the retile whose restore pass
    /// delivers it. A pure decision: the delivery, its echo
    /// bookkeeping and the top-bar push stay the restore's and the
    /// clamp's.
    func recoverStrandedFloats() {
        for space in state.workspaces.visibleSpaces {
            guard let workspace = state.workspaces[space]
            else { continue }
            for id in workspace.windows {
                guard let window = state.windows[id],
                    id != tiler.dragExemptWindow,
                    // Never parked ⇒ never stranded: the verdict
                    // the park decides on (#445).
                    state.parksOnInactive(window, in: space),
                    // EFFECTIVE float, never the flag (#1178), on the
                    // stored mode: tiling off leaves a layout's park
                    // where it is until resume places it (#3008).
                    EffectiveFloat.applies(
                        isFloating: window.isFloating,
                        mode: workspace.mode
                    ),
                    tiler.stashOriginal(id) == nil,
                    tiler.looksStashed(window.frame)
                else { continue }
                seedWithoutOriginal(id, in: space)
            }
        }
    }

    /// The one door for a float with no original — stranded at a
    /// corner, or replayed from a corner record (#2130): centred
    /// at its own size in the float region, never resized (#3163),
    /// as a pending capture the restore delivers. False where the
    /// Space has no region.
    @discardableResult
    func seedWithoutOriginal(_ id: WindowID, in space: SpaceID) -> Bool {
        guard let window = state.windows[id],
            let region = floatBounds(on: space)
        else { return false }
        tiler.seedStash(
            id,
            frame: FloatRecovery.centredAtSize(
                window.frame.size,
                in: region
            )
        )
        onLog("float \(id) has no original on space \(space); re-centring")
        return true
    }

    /// The session snapshot the crash and sleep legs write —
    /// every `captureState` consumer takes this, never
    /// `state.snapshot()`: state, with a maximized float's return
    /// frame (#3036), else a parked float's CAPTURE, in place of its
    /// state frame. The state frame of a parked
    /// float is the corner, and a restore replaying it verbatim
    /// put the window back there with nothing left to undo it.
    ///
    /// `inPlace` adds the session memory only an in-place restart
    /// carries (#930, `StateSnapshot+InPlace`), the Monocle hold
    /// included.
    func sessionSnapshot(inPlace: Bool = false) -> StateSnapshot {
        var snapshot =
            inPlace
            ? state.inPlaceSnapshot(
                monocleShown: tiler.monocleShownMembers,
                ratios: sessionSizing(of:)
            )
            : state.snapshot()
        snapshot.arrangement = liveArrangement
        snapshot.arrangementRecords = partitioningForSnapshot()
        // Whether a Space is temporary is Core's to say, and its
        // pin is in no arrangement, so its record carries both
        // (#1790).
        for index in snapshot.spaces.indices {
            let id = SpaceID(snapshot.spaces[index].id)
            guard isTemporary(id) else { continue }
            snapshot.spaces[index].temporary = .init(
                armed: state.temporaryArmed.contains(id),
                pin: spacePins[id]
            )
        }
        // Only the frames change; every other field rides as
        // captured (the held Spaces, #1646).
        return snapshot.mappingWindowRecords { record in
            // A maximized float records its return, never the fill,
            // so no restore leaves it full size (#3036).
            guard
                let original = state.maximizedFloatReturn[
                    record.windowID
                ]?.frame ?? tiler.stashOriginal(record.windowID)
            else { return record }
            var copy = record
            copy.frame = original
            return copy
        }
    }
}

/// The centring arithmetic, pure so a fixture can pin it.
public enum FloatRecovery {
    /// `size` centred in `region` and never resized (#3163): a net
    /// placing a float the user sized. Larger than the region, its
    /// top-left edge stays in the region, so its title bar is in
    /// reach, and the rest runs past the far edge.
    public static func centredAtSize(
        _ size: CGSize,
        in region: CGRect
    ) -> CGRect {
        CGRect(
            x: max(region.minX, region.midX - size.width / 2),
            y: max(region.minY, region.midY - size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    /// `size` centred in `region`, shrunk to fit where it is
    /// larger: a placement for a float verb the user started (a
    /// Pocket take-out, a Maximize's return to another screen).
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
