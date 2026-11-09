import Foundation

/// A lens turning on opens its Auto-open apps that have no window
/// (#3122 ▸ Ruling amendment): each judged on its own, all opened
/// in the background, and one focus move owed to the first member
/// window to arrive where none of the lens's apps had one.
extension KiwiCore {
    /// Called by the user doors alone, after the lens went on:
    /// `toggleCommand` and `setKiwiVision`, never `setVision`, and
    /// never inside a config load.
    func openLensApps(_ lens: VisionLens) {
        guard !vision.configLoading else { return }
        let open = Set(lens.apps.filter(lensMemberHasWindow))
        var queued: Set<String> = []
        var missing: [String] = []
        for app in lens.openApps
        where !open.contains(app) && lens.autoOpenBlock(app) == nil {
            if launchInBackground(app) {
                queued.insert(app)
            } else {
                missing.append(app)
            }
        }
        if !queued.isEmpty {
            onLog("kiwivision: \(lens.name) opened \(queued.sorted())")
            launchFollow.noteQuietApps(queued, at: wallClock())
        }
        guard open.isEmpty else { return }
        if !queued.isEmpty {
            oweQuietOpenFocus(queued, lens: lens.name)
            return
        }
        noteLensNotice(
            missing.first.map { .notInstalled(app: $0) }
                ?? .noMemberOpen(lens: lens.name)
        )
    }

    /// Whether the member `app` has a window: one KiwiDesk tracks
    /// (the pocket's included, in either phase), one minimized, or
    /// one on another Desktop. A tracked-state read, never a census;
    /// a ⌘H-hidden app's windows are in none of the three.
    func lensMemberHasWindow(_ app: String) -> Bool {
        func key(_ bundleID: String?, _ name: String) -> String {
            AppRef(bundleID: bundleID, name: name).listKey
        }
        return state.windows.all.contains { $0.appRef.listKey == app }
            || state.minimizeOrder.contains { key($0.bundleID, $0.app) == app }
            || state.awayWindows.values.contains {
                key($0.appBundleID, $0.appName) == app
            }
    }

    /// The one focus move a quiet open owes (#3122), owed through
    /// the launch follow's door (#1599): stamped with the focus and
    /// the front app at the press, which its cancels compare against.
    private func oweQuietOpenFocus(_ apps: Set<String>, lens: String) {
        let focus = focusedWindowID
        let open = LaunchFollowIntent.QuietOpen(
            bundleIDs: apps,
            lens: lens,
            focus: focus,
            front: focus.flatMap { state.windows[$0]?.appBundleID }?
                .lowercased(),
            at: wallClock()
        )
        oweLaunchFollow(quietly: open)
    }

    /// Pays the quiet open's one focus move at `window`'s arrival;
    /// true where the window claimed the debt. Focus moves only
    /// while the focus is the press's, no click came since, the lens
    /// is still on and a screen shows the window's Space; KiwiDesk
    /// switches no Space or Desktop for it, so a window its app rule
    /// files in a hidden Space spends the move and stays there.
    func claimQuietOpen(arrived window: ManagedWindow) -> Bool {
        guard !eventLoop.switchReads.applying,
            state.windows[window.id]?.isTransientOverlay == false,
            let owed = launchFollow.claimQuiet(
                window.appRef.listKey,
                at: wallClock()
            )
        else { return false }
        let clicked = lastLeftClick.map { $0.at > owed.at } ?? false
        let lensOn = visionLensName.map {
            AppWideSettings.sameLens($0, owed.lens)
        }
        let space = state.workspaces.space(of: window.id)
        let shown =
            space.flatMap { state.workspaces.display(of: $0) }
            .map { state.workspaces.activeSpace(on: $0) == space }
            ?? (space == state.workspaces.activeSpace)
        guard focusedWindowID == owed.focus, !clicked, lensOn == true,
            shown
        else {
            onLog("kiwivision: w\(window.id.raw) arrived — focus stays")
            return true
        }
        onLog("kiwivision: focus handed to w\(window.id.raw)")
        focusWindow(window.id, refocusRetile: false, warp: true)
        return true
    }
}
