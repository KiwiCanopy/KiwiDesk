import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are
/// blocking IPC; running them here keeps the main thread free
/// and their order strict.
private let zOrderQueue = DispatchQueue(
    label: "org.kiwidesk.zorder",
    qos: .userInteractive
)

/// Z-order maintenance for the layouts whose windows overlap:
/// stack's cascade and scrolling's edge piles.
extension KiwiCore {
    /// Requests a z-order restore after something scrambled
    /// the stacking (zone crossings, mode switches, native
    /// space switches, profile loads). Deferred until all
    /// animations settle: a raise is only processed once the
    /// target app's main thread is free, and while frames are
    /// still being applied, slow apps process their raise
    /// late and end up out of order.
    func scheduleZOrderRestore() {
        pendingZOrderRestore = true
        if tiler.animation.activeCount == 0 {
            runPendingZOrderRestore()
        }
    }

    /// Schedules a scrolling edge-pile restack after a swap, but
    /// only when the row overflows the viewport (#150): a fully
    /// visible row has no piles, so nothing overlaps and a swap
    /// scrambles no stacking. Call *after* the swap's retile, so
    /// the restore rides the new animations' settle rather than
    /// firing from the pre-swap frames (the #153 ordering rule).
    func scheduleScrollingZOrderRestoreIfOverflowing() {
        guard let input = tiler.layoutInput(state: state),
            input.space.mode == .scrolling,
            ScrollingLayout.rowOverflows(
                for: input.tiled,
                in: input.context
            )
        else { return }
        scheduleZOrderRestore()
    }

    /// Requests a z-order restore whose paired retile is the
    /// command dispatcher's own trailing `retile(force:)`, not
    /// one issued at the call site (#153). Recorded, not armed:
    /// `layoutCommand` fires `scheduleZOrderRestore` *after* that
    /// retile, so the restore can't run mid-retile off pre-retile
    /// frames and be consumed before the new animations begin.
    /// `promoteDemote` is the one such site (its reorder's retile
    /// belongs to the dispatcher).
    func requestZOrderRestoreAfterDispatch() {
        deferredCommandZOrderRestore = true
    }

    /// Runs a scheduled restore (called when animations end).
    func runPendingZOrderRestore() {
        guard pendingZOrderRestore else { return }
        pendingZOrderRestore = false
        guard let space = activeSpace else { return }
        switch space.mode {
        case .stack:
            restoreStackZOrder(space)
        case .scrolling:
            restoreScrollingZOrder(space)
        case .track:
            restoreTrackZOrder(space)
        default:
            break
        }
    }

    /// Track (#193): an overflow cascade piles windows — the
    /// windows inside one track, or whole buried tracks — with
    /// the title-bar offset. Array order IS the cascade order
    /// everywhere in the track model (each pile is a contiguous
    /// slice), so raising the tiled windows in that order puts
    /// every pile's first window behind and its last in front,
    /// keeping each title bar visible. The focused window is
    /// re-raised last — the same override as the stack cascade.
    private func restoreTrackZOrder(_ space: Space) {
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard tiled.count > 1 else { return }
        raiseSequentially(tiled, thenFocus: space.focused)
    }

    /// Schedules a track z-order restore, but only when the
    /// layout actually cascades (the scrolling gate's twin,
    /// #150): tracks that tile side by side don't overlap, so a
    /// reorder scrambles no stacking and a needless re-raise
    /// would flicker focus. Call *after* the reorder's retile.
    func scheduleTrackZOrderRestoreIfOverflowing() {
        guard let input = tiler.layoutInput(state: state),
            input.space.mode == .track,
            Self.framesCascade(
                TrackLayout().calculateGeometry(
                    for: input.tiled,
                    in: input.context
                )
            )
        else { return }
        scheduleZOrderRestore()
    }

    /// Whether any two laid-out frames overlap — the signature
    /// of an overflow cascade. Tiled tracks never overlap (the
    /// inner gaps separate them), so this is false whenever the
    /// space fits without piling. Pure math, unit-tested.
    nonisolated static func framesCascade(
        _ frames: [WindowID: CGRect]
    ) -> Bool {
        let rects = Array(frames.values)
        for i in rects.indices {
            for j in (i + 1)..<rects.count
            where !rects[i].intersection(rects[j]).isEmpty {
                return true
            }
        }
        return false
    }

    /// Re-raises the stack zone top to bottom, so upper
    /// windows sit behind lower ones and every title bar of
    /// the cascade stays visible. A plain focus change still
    /// brings the focused window to the front, which is the
    /// expected override.
    private func restoreStackZOrder(_ space: Space) {
        // Per-space master boundary (#17), matching layout math.
        let boundary = max(
            1,
            tiler.settings.resolvedStack(for: space.id).masterCount
        )
        guard space.windows.count > boundary else { return }
        raiseSequentially(
            Array(space.windows[boundary...]),
            thenFocus: space.focused
        )
    }

    /// Scrolling: columns pushed past the screen edges are
    /// clamped there by macOS and pile up, overlapping. Each
    /// side must stack toward its own edge — the column
    /// nearest the focus on top, farther ones underneath —
    /// so the piles read as the row receding to the left and
    /// to the right of the viewport.
    private func restoreScrollingZOrder(_ space: Space) {
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard tiled.count > 1 else { return }
        let focusIndex =
            space.focused.flatMap {
                tiled.firstIndex(of: $0)
            } ?? 0
        raiseSequentially(
            Self.scrollingRaiseOrder(
                tiled,
                focusIndex: focusIndex
            ),
            thenFocus: space.focused
        )
    }

    /// The raise sequence for the scrolling piles: both sides
    /// run farthest-from-focus first, so every raise lands on
    /// top of the previous one — the left pile ascending, the
    /// right pile descending. The focused window itself is
    /// left out; the closing focus re-assert puts it on top.
    /// Pure math, unit-tested.
    nonisolated static func scrollingRaiseOrder(
        _ windows: [WindowID],
        focusIndex: Int
    ) -> [WindowID] {
        guard windows.indices.contains(focusIndex) else {
            return windows
        }
        return Array(windows[..<focusIndex])
            + windows[(focusIndex + 1)...].reversed()
    }

    /// Raises the windows in exactly the given order. Raises
    /// run sequentially on one queue: each call returns only
    /// after the target app processed it, which keeps the
    /// order across apps.
    private func raiseSequentially(
        _ ids: [WindowID],
        thenFocus focused: WindowID?
    ) {
        let ordered = ids.compactMap {
            eventLoop.element(for: $0)
        }
        guard !ordered.isEmpty else { return }
        nonisolated(unsafe) let elements = ordered
        zOrderQueue.async { [weak self] in
            for element in elements {
                AXHelper.raiseQuietly(element)
            }
            // AXRaise on a window of the ACTIVE app makes it
            // key (AppKit's handler does makeKeyAndOrderFront),
            // so the sequence steals focus window by window.
            // Re-assert the intended focus as the ordered
            // final step of the same sequence.
            guard let focused else { return }
            Task { @MainActor [weak self] in
                self?.focusWindow(focused)
            }
        }
    }

    /// Whether swapping these two windows moves one across
    /// the stack layout's master/stack boundary.
    func crossesStackBoundary(
        _ a: WindowID,
        _ b: WindowID,
        in space: Space
    ) -> Bool {
        guard space.mode == .stack else { return false }
        // Per-space master boundary (#17), matching layout math.
        let boundary = max(
            1,
            tiler.settings.resolvedStack(for: space.id).masterCount
        )
        guard let indexA = space.windows.firstIndex(of: a),
            let indexB = space.windows.firstIndex(of: b)
        else { return false }
        return (indexA < boundary) != (indexB < boundary)
    }
}
