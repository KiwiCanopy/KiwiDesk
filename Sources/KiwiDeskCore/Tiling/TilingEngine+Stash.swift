import AppKit
import CoreGraphics

// MARK: - Hiding inactive virtual spaces

extension TilingEngine {
    /// Visible sliver of stashed windows: the WindowServer's
    /// clamp floor plus this sliver's own margin (see
    /// `WindowServerFacts.visibilityFloor`). An ask below the
    /// floor (the old 8 pt) was unreachable — the OS lifted it
    /// to ~32 pt, the ±2 pt tolerance never passed, and
    /// `stashInactive` re-issued a frame for every
    /// inactive-space window on every retile (#148). At
    /// floor + margin the target is achievable, so stashed
    /// windows settle; the visible change is marginal (the OS
    /// already showed ~32–40 pt).
    nonisolated static let stashPeek: CGFloat =
        WindowServerFacts.visibilityFloor + 8

    /// Where a hidden window parks: the bottom-right corner
    /// of its screen, AeroSpace style (only the top-left
    /// `stashPeek` corner remains visible). Size unchanged.
    nonisolated static func stashFrame(
        _ frame: CGRect,
        in bounds: CGRect
    ) -> CGRect {
        CGRect(
            x: bounds.maxX - stashPeek,
            y: bounds.maxY - stashPeek,
            width: frame.width,
            height: frame.height
        )
    }

    /// Hides every inactive virtual space's windows — tiled
    /// AND floating (#412): a floating window belongs to one
    /// space and hides with it, exactly like a tiled one.
    /// (Windows meant to be visible everywhere are the Sticky
    /// capability, #414 — not a floating side effect.)
    ///
    /// Tiled windows come back through the normal retile when
    /// their space is activated again; floating windows come
    /// back through `restoreStashed`, from the frame captured
    /// here on their first stash.
    func stashInactive(
        state: StateCoordinator,
        fallback: NSScreen,
        force: Bool
    ) {
        guard let active = state.workspaces.activeSpace
        else { return }
        for space in state.workspaces.allSpaces
        where space.id != active {
            for id in space.windows {
                guard let window = state.windows[id],
                    id != dragExemptWindow
                else { continue }
                let screen =
                    NSScreen.screens.first {
                        GeometryUtils.axVisibleFrame(of: $0)
                            .intersects(window.frame)
                    } ?? fallback
                stash(
                    window,
                    in: GeometryUtils.axVisibleFrame(
                        of: screen
                    ),
                    force: force
                )
            }
        }
    }

    /// Parks one window at the stash corner of `bounds`. A
    /// sticky window is exempt — present on every space is the
    /// whole feature (#414), so it stays in place when its home
    /// space goes inactive. A floating window's original frame
    /// is captured on its first stash — no layout recomputes a
    /// floating frame, so the restore pass needs it. Guarded on
    /// nil: a later forced re-stash (whose state frame is
    /// already the AX echo of the corner) must not overwrite
    /// the original.
    func stash(
        _ window: ManagedWindow,
        in bounds: CGRect,
        force: Bool
    ) {
        guard !window.isSticky else { return }
        let target = Self.stashFrame(window.frame, in: bounds)
        if !force, Self.close(window.frame, to: target) {
            return
        }
        if window.isFloating,
            stashedFrames[window.id] == nil
        {
            stashedFrames[window.id] = window.frame
        }
        animation.cancel(window: window.id)
        setFrame(window.id, target)
    }

    /// Restores the active space's stashed floating windows to
    /// their captured frames. Runs on every retile after the
    /// layout frames apply; every space switch retiles with
    /// `force: true`, which bypasses the ±2 pt tolerance — the
    /// restore itself is deliberately NOT gated behind that
    /// tolerance, so it cannot be swallowed by echo lag.
    ///
    /// A window that got a layout frame this retile (unfloated
    /// while stashed) is the layout's to place: its entry is
    /// dropped, not re-applied. Entries for windows that left
    /// the state (closed, or re-keyed by a native-tab switch,
    /// #308) are swept so the map cannot grow stale ids.
    func restoreStashed(
        state: StateCoordinator,
        frames: [WindowID: CGRect]
    ) {
        guard
            let active = state.workspaces.activeSpace,
            let space = state.workspaces[active]
        else { return }
        for id in space.windows {
            guard let original = stashedFrames[id]
            else { continue }
            stashedFrames[id] = nil
            guard frames[id] == nil, id != dragExemptWindow
            else { continue }
            animation.cancel(window: id)
            setFrame(id, original)
        }
        stashedFrames = stashedFrames.filter {
            state.windows[$0.key] != nil
        }
    }
}
