import Foundation

/// `gather` (#1510): every window of an app into the Space the
/// user is on. A tracked window is filed through the one
/// `fileMembership`; a window up on another macOS Desktop of the
/// same screen (#1146) is MOVED onto the Desktop that screen shows
/// — a hop, never a switch — and, once the bridge accepted, has
/// its remembered Space pointed at the target, so its arrival
/// files it there. Nothing launches: an app with no window to
/// gather is cued and refused.
extension KiwiCore {
    func gather(_ args: [JSONValue]) -> CommandResponse {
        guard let bundleID = args.first?.stringValue?.lowercased()
        else { return .fail("expected app bundle id") }
        guard let target = state.workspaces.activeSpace else {
            return .fail("no active Space to gather into")
        }
        let local = gatherableWindows(bundleID: bundleID, into: target)
        let hop = hopAwayWindows(bundleID: bundleID, into: target)
        let hopped = hop ?? []
        if local.isEmpty, hop == nil {
            onLog("gather: \(bundleID) — the bridge refused the move")
            return .fail("could not move \(bundleID) from another Desktop")
        }
        guard !local.isEmpty || !hopped.isEmpty else {
            cueNothingToGather(bundleID: bundleID)
            return .fail("no \(bundleID) window outside this Space")
        }
        for id in local {
            fileMembership(
                id,
                into: target,
                from: state.workspaces.space(of: id)
            )
        }
        onLog(
            "gather: \(bundleID) — \(local.count) window(s) filed into "
                + "space \(target.raw), \(hopped.count) move(s) "
                + "dispatched from other Desktops"
        )
        // The first gathered window is the focus, raised and keyed
        // the way a window moved INTO the active Space is — the
        // state trackers alone would leave the ring on a window
        // macOS never focused (#292's anchor).
        if let first = local.first {
            focusWindow(first, refocusRetile: false, warp: true)
            retile(animated: true)
        }
        return .ok()
    }

    /// The app's tracked windows outside `target`, in Space order
    /// then slot order — the Space Bar's reading order. A native
    /// fullscreen window keeps its own Space (#670), and a sticky
    /// move the #445 gate refuses stays where it is.
    func gatherableWindows(
        bundleID: String,
        into target: SpaceID
    ) -> [WindowID] {
        let landing = landingDisplay(of: target)
        return state.workspaces.allSpaces
            .filter { $0.id != target }
            .flatMap(\.windows)
            .filter { id in
                guard let window = state.windows[id],
                    window.appBundleID?.lowercased() == bundleID,
                    !window.isFullscreen
                else { return false }
                return !stickyMoveRefused(
                    id,
                    to: target,
                    landingOn: landing
                )
            }
    }

    /// Moves the app's windows up on another Desktop of `target`'s
    /// screen onto the Desktop that screen shows, and only once the
    /// bridge accepted points each one's remembered Space at
    /// `target`. Another screen's Desktop is left alone: the
    /// arrival's screen-home net (#1010) would file it there. An
    /// UNFILED entry — no remembered Space at all — is skipped
    /// too, since its arrival would take its app rule. Performed
    /// is not applied (os-private-apis.md): the arrival, or the
    /// reap's reconcile, is the verification. Returns the windows
    /// whose move was dispatched, or nil where the bridge refused.
    private func hopAwayWindows(
        bundleID: String,
        into target: SpaceID
    ) -> [WindowID]? {
        guard canDriveDesktops,
            let reach = awayReach(bundleID: bundleID),
            let uuid = state.workspaces.display(of: target)
                .flatMap(NativeSpaces.displayUUID(for:))
                ?? reach.snapshot.mainUUID,
            let shown = reach.snapshot.currentSpaces[uuid]
        else { return [] }
        let windows = reach.windows.map(\.window).filter { window in
            state.rememberedSpaces[window.id] != nil
                && reach.snapshot.spaces.first {
                    $0.id == window.nativeSpace
                }?.displayUUID == uuid
        }
        guard !windows.isEmpty else { return [] }
        guard WMBridge.moveWindows(windows.map(\.id), to: shown) else {
            return nil
        }
        for window in windows {
            state.refileAway(of: window.id, to: target)
        }
        // Every gather inside the delay adds to the one reap.
        desktopMemory.gatherReapPIDs.formUnion(windows.map(\.pid))
        deferred.schedule(.gatherReap, after: .milliseconds(700)) {
            [weak self] in
            guard let self else { return }
            let pids = self.desktopMemory.gatherReapPIDs
            self.desktopMemory.gatherReapPIDs = []
            guard self.eventLoop.isRunning else { return }
            // Off the main actor (#1930): the arrival's own
            // retile places what each read adopts.
            for pid in pids.sorted() {
                self.eventLoop.reconcileOffMain(
                    pid: pid,
                    app: AppRef(pid: pid)
                ) { [weak self] in self?.retile(animated: true) }
            }
        }
        return windows.map(\.id)
    }

    /// The refusal a key press would otherwise meet in silence:
    /// drawn on the focused window, naming the app.
    private func cueNothingToGather(bundleID: String) {
        let app =
            state.windows.all.first {
                $0.appBundleID?.lowercased() == bundleID
            }?.appName ?? bundleID
        guard let focused = state.workspaces.lastFocused else {
            onLog("gather: nothing of \(bundleID) to gather")
            return
        }
        cueWindowAction(.nothingToGather(app: app), on: focused)
    }
}
