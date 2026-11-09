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

    /// Whether the member `app` has a window: one KiwiDesk tracks,
    /// one minimized, or one on another Desktop. A tracked-state
    /// read, never a census.
    func lensMemberHasWindow(_ app: String) -> Bool {
        state.windows.all.contains { $0.appRef.listKey == app }
            || state.minimizeOrder.contains {
                ($0.bundleID ?? $0.app.lowercased()) == app
            }
            || state.awayWindows.values.contains {
                $0.appBundleID?.lowercased() == app
            }
    }

    /// The one focus move a quiet open owes (#3122), through the
    /// launch follow's ledger (#1599): stamped with the focus and
    /// front app at the press, which its cancels compare against.
    private func oweQuietOpenFocus(_ apps: Set<String>, lens: String) {
        let focus = focusedWindowID
        launchFollow.recordQuiet(
            .init(
                bundleIDs: apps,
                lens: lens,
                focus: focus,
                front: focus.flatMap { state.windows[$0]?.appBundleID }?
                    .lowercased(),
                at: wallClock()
            )
        )
    }

    /// A quiet open's debt claimed at an arrival, and the Space its
    /// window's app rule owes a follow into, nil for none.
    struct QuietOpenPaid { let follow: SpaceID? }

    /// Pays the quiet open's focus move on `window`'s arrival, nil
    /// where the window owes it nothing. Focus moves only while the
    /// focus is the press's, no click came since and the lens is
    /// still on; `focusWindow` refuses a window no screen shows,
    /// and KiwiDesk switches no Desktop for it.
    func claimQuietOpen(
        arrived window: ManagedWindow,
        effects: AppliedEffects
    ) -> QuietOpenPaid? {
        guard !eventLoop.switchReads.applying,
            !window.isTransientOverlay,
            let owed = launchFollow.claimQuiet(
                window.appRef.listKey,
                at: wallClock()
            )
        else { return nil }
        let clicked = lastLeftClick.map { $0.at > owed.at } ?? false
        let lensOn = visionLensName.map {
            AppWideSettings.sameLens($0, owed.lens)
        }
        guard focusedWindowID == owed.focus, !clicked, lensOn == true
        else {
            onLog("kiwivision: w\(window.id.raw) arrived — focus stays")
            return QuietOpenPaid(follow: nil)
        }
        if let space = effects.placedByAppRule,
            state.workspaces.space(of: window.id) == space
        {
            return QuietOpenPaid(follow: space)
        }
        onLog("kiwivision: focus handed to w\(window.id.raw)")
        focusWindow(window.id, refocusRetile: false, warp: true)
        return QuietOpenPaid(follow: nil)
    }
}
