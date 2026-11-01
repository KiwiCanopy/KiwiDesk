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
            return stepKeyedPocket(slot)
        }
        // A window this press's twin already asked for is on its way.
        if let claim = arrivals.livePocketClaim(
            for: bundleID,
            at: wallClock()
        ), !claim.spent {
            onLog("pocket: \(bundleID)'s window is still on its way")
            return .ok()
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

    /// The app's own window in or out; a hidden app is shown, its
    /// window coming back to the slot.
    private func stepKeyedPocket(_ slot: PocketSlot) -> CommandResponse {
        let id = slot.window
        guard state.windows[id] != nil else {
            guard let pid = slot.pid, eventLoop.processIdentity.runs(pid)
            else { return .fail("pocket is unreachable") }
            openOrFocus.activate(pid)
            return .ok()
        }
        if state.isPocketed(id) {
            return takePocketOut(id)
                ? .ok() : .fail("pocket is unreachable")
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
        arrivals.pocketClaims[bundleID] = .init(
            bundleID: bundleID,
            keyed: keyed,
            at: wallClock()
        )
        guard let pid = openOrFocus.runningAppPID(bundleID),
            showsAnyWindow(openOrFocus.census(pid))
        else {
            guard openOrFocus.openApp(bundleID, false) else {
                arrivals.pocketClaims[bundleID] = nil
                return .fail("app not found: \(bundleID)")
            }
            onLog("pocket: opening \(bundleID) for its Pocket key")
            return .ok()
        }
        openOrFocus.activate(pid)
        windowActions.newWindow(pid) { [weak self] pressed in
            guard !pressed, let self else { return }
            // Nothing opened, so nothing is claimed.
            self.arrivals.pocketClaims[bundleID] = nil
            guard let window = self.state.windows.windows(pid: pid).first
            else { return }
            self.cueWindowAction(
                .noNewWindow(app: window.appName),
                on: window.id
            )
        }
        return .ok()
    }

    /// A reopen with only minimized windows brings one back rather
    /// than opening a new one, so they count.
    private func showsAnyWindow(_ census: AppWindowCensus) -> Bool {
        census.visible + census.minimized.count > 0
    }

    /// A general-list verb on a window its app's key owns (#2612
    /// ▸ 1): refused on it, naming the key the GUI reads live —
    /// drawn as its glyphs, spoken in words (#2601).
    func refuseKeyedPocketWindow(
        _ id: WindowID,
        app: String
    ) -> CommandResponse {
        let chord = barMenuHooks.pocketKeyChord(app)
        soundIfDrawn(
            flashRefusalPill(
                id,
                text: PocketRefusal.keyedSentence(chord: chord?.drawn),
                symbol: AutoFloatReason.pocket.pillSymbol,
                announce: true,
                spoken: PocketRefusal.keyedSentence(chord: chord?.spoken)
            )
        )
        return .fail("this window has a Pocket key of its own")
    }
}
