import Foundation

/// `pocket_app <bundle id>` (#2612): an app's own Pocket key. Its
/// window goes in and out of the pocket by this verb alone; with
/// none, the press opens a fresh window of the app, launching it if
/// needed, which arrives out (▸ 9). The tie needs the app's
/// Shortcuts row (▸ 10): without one the window joins the general
/// list under its capacity. Acts on its app, never the focus.
extension KiwiCore {
    func pocketAppCommand(_ args: [JSONValue]) -> CommandResponse {
        guard case .string(let raw)? = args.first, !raw.isEmpty else {
            return .fail("expected app bundle id")
        }
        let bundleID = raw.lowercased()
        if emptyPocketIfGone() { updatePocketPlate() }
        if let slot = state.pocketSlot(ownedBy: bundleID) {
            return stepKeyedPocket(slot.window)
        }
        let keyed = pocketAppRows().contains(bundleID)
        guard keyed || state.pocketAcceptsMark(appWide.pocketCapacity)
        else {
            guard let focused = focusedWindowID else {
                return .fail("another window is the pocket window")
            }
            return refuseSecondPocketWindow(focused)
        }
        return openPocketAppWindow(bundleID, keyed: keyed)
    }

    /// The app's own window in or out.
    private func stepKeyedPocket(_ id: WindowID) -> CommandResponse {
        if state.isPocketed(id) {
            return takePocketOut(id)
                ? .ok() : .fail("pocket is unreachable")
        }
        guard state.windows[id] != nil else {
            return .fail("pocket is unreachable")
        }
        putInPocket(id)
        return .ok()
    }

    /// Opens a window of `bundleID` whose arrival the claim takes:
    /// a launch, a reopen where the app shows no window, else its
    /// New Window row.
    private func openPocketAppWindow(
        _ bundleID: String,
        keyed: Bool
    ) -> CommandResponse {
        arrivals.pocketClaim = .init(
            bundleID: bundleID,
            keyed: keyed,
            at: wallClock()
        )
        guard let pid = openOrFocus.runningAppPID(bundleID),
            openOrFocus.census(pid).visible > 0
        else {
            guard openOrFocus.openApp(bundleID, false) else {
                arrivals.pocketClaim = nil
                return .fail("app not found: \(bundleID)")
            }
            onLog("pocket: opening \(bundleID) for its Pocket key")
            return .ok()
        }
        openOrFocus.activate(pid)
        windowActions.newWindow(pid) { [weak self] pressed in
            guard !pressed, let self else { return }
            // Nothing opened, so nothing is claimed.
            if self.arrivals.pocketClaim?.bundleID == bundleID {
                self.arrivals.pocketClaim = nil
            }
            guard let window = self.state.windows.windows(pid: pid).first
            else { return }
            self.cueWindowAction(
                .noNewWindow(app: window.appName),
                on: window.id
            )
        }
        return .ok()
    }

    /// A general-list verb on a window its app's key owns (#2612
    /// ▸ 1): refused on it, naming the key the GUI reads live.
    func refuseKeyedPocketWindow(
        _ id: WindowID,
        app: String
    ) -> CommandResponse {
        soundIfDrawn(
            flashRefusalPill(
                id,
                text: PocketRefusal.keyedSentence(
                    chord: barMenuHooks.pocketKeyChord(app)
                ),
                symbol: AutoFloatReason.pocket.pillSymbol,
                announce: true
            )
        )
        return .fail("this window has a Pocket key of its own")
    }
}
