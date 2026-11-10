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
        let open = Set(lens.apps.filter(hasWindow(app:)))
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

    /// The one focus move a quiet open owes (#3122), owed through
    /// the launch follow's door (#1599): stamped with the focus and
    /// the front app at the press, which its cancels compare against.
    private func oweQuietOpenFocus(_ apps: Set<String>, lens: String) {
        let focus = focusedWindowID
        let open = LaunchFollowIntent.QuietOpen(
            bundleIDs: apps,
            purpose: .lens(lens),
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
        guard !eventLoop.switchReads.applying else { return false }
        guard state.windows[window.id]?.isTransientOverlay == false,
            let owed = launchFollow.claimQuiet(
                window.appRef.listKey,
                at: wallClock()
            )
        else { return false }
        let clicked = lastLeftClick.map { $0.at > owed.at } ?? false
        guard case .lens(let lens) = owed.purpose else { return false }
        let lensOn = visionLensName.map {
            AppWideSettings.sameLens($0, lens)
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
