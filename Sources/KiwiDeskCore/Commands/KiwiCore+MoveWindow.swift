import AppKit
import Foundation

/// The window move behind `move_to_space(_and_follow)`, the Space
/// Bar drop and the window-id swap's trade (#2509), split from
/// `KiwiCore+SpaceCommands` at the §2.1 ceiling.
extension KiwiCore {
    func moveToSpace(
        _ command: String,
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        switch commandTarget(command, args) {
        case .refused(let response): return response
        case .window(let window):
            guard !state.isPocketed(window) else {
                return .fail("window \(window.raw) is in the pocket")
            }
            let target = SpaceID(raw)
            if state.workspaces.space(of: window) == target,
                stickyMoveBlock(window, to: target) == nil
            {
                return moveIntoOwnSpace(window, target, follow: follow)
            }
            moveWindow(window, to: target, follow: follow)
            return .ok()
        }
    }

    /// A move into the window's own Space re-files nothing: a
    /// follow into an unshown one switches there, anything else
    /// refuses with a pill naming the window.
    private func moveIntoOwnSpace(
        _ window: WindowID,
        _ target: SpaceID,
        follow: Bool
    ) -> CommandResponse {
        if follow, target != state.workspaces.activeSpace {
            followSwitch(to: target, focusing: window)
            return .ok()
        }
        let name = state.windows[window].map {
            $0.title.isEmpty ? $0.appName : $0.title
        }
        cueWindowAction(
            .alreadyIn(window: name ?? "", space: target.raw),
            on: window
        )
        return .fail("window \(window.raw) is already in \(target.raw)")
    }

    /// Relocates an explicit `window` into `target`. `follow`
    /// switches the visible space to the target; otherwise the
    /// caller's space stays put and the moved window becomes the
    /// target's focus for its next visit. The window-explicit
    /// core behind `move_to_space(_and_follow)` and the Space Bar
    /// drag-drop (#372) — the drag knows the window id, the
    /// command resolves the focused one. When the target is
    /// already the active space (a Space Bar spring drop), this
    /// files the window into the visible layout and focuses it.
    ///
    /// Sticky moves are guarded up front via `stickyMoveRefused`
    /// (#445) — the same gate the Space-Bar spring calls, since
    /// `addFocusedToSpace` (not `moveWindow`) is the real re-home
    /// choke point and has two callers. `trading` sends that
    /// window the other way, into `window`'s slot (#2509); its
    /// caller asks the sticky gate for it, `swapWindows` the one.
    func moveWindow(
        _ window: WindowID,
        to target: SpaceID,
        follow: Bool,
        trading partner: WindowID? = nil
    ) {
        let from = state.workspaces.space(of: window)
        // A pocketed window is filed by its own key alone (#2446).
        guard !state.isPocketed(window),
            partner.map({ !state.isPocketed($0) }) ?? true
        else {
            onLog("move: w\(window.raw) refused — in the pocket")
            return
        }
        // Told where an undeclared target WILL lay out (#1994).
        if stickyMoveRefused(
            window,
            to: target,
            landingOn: landingDisplay(of: target)
        ) {
            return
        }
        // Captured before the focus reassign below overwrites it:
        // whether the moved window currently holds OS key focus.
        // Only then must an emptied origin yield focus (#446).
        // A trade moves both windows, so either may be the one
        // holding focus (#2509).
        let held = state.workspaces.lastFocused
        let movedHeldFocus =
            held == window || (held != nil && held == partner)
        if let partner {
            fileTrade(window, partner)
            if !follow { moveLatch.stamp(partner) }
        } else {
            fileMembership(window, into: target, from: from)
        }
        if !follow {
            // A no-follow move must not be turned into a follow
            // by the OS dropping the origin refocus raise below
            // (#463's cooperative activate): the moved window
            // then keeps key focus, its app re-reports it
            // AX-focused, and the focus-follow would teleport
            // the user to the target (#482/#483). Latch the
            // intent — every no-follow branch shares the hazard
            // (in the yield branch, the Finder activate can even
            // BE the moved window's app: a floating Finder
            // window, #483).
            moveLatch.stamp(window)
        }
        if follow {
            // The one copy of the follow-shaped switch — the
            // capture/raise/settle ordering lives on it.
            followSwitch(to: target, focusing: window)
        } else if movedHeldFocus
            || from == state.workspaces.activeSpace
            || target == state.workspaces.activeSpace,
            let next = activeSpace?.focused
        {
            // A window moved between Spaces nobody is on, holding
            // no focus, leaves the active Space's focus alone
            // (#1518); one moved INTO it is that focus.
            // Captured before the refocus raise below — the
            // settle's dropped-activate detection (#463 pattern).
            let priorFrontmost = frontmostPIDProvider?()
            // The moved window would keep macOS focus while
            // stashed offscreen; refocus the current space.
            focusWindow(next, refocusRetile: false, warp: true)
            // Arm the settle that re-raises `next` once when the
            // moved window's app provably kept frontmost. Only a
            // move that held key focus can leave that hazard;
            // otherwise `priorFrontmost` is whatever app the
            // user is really in — never fight it. The gate reads
            // the RING (`lastFocused`), which the hazard itself
            // can leave stale: then the settle is skipped and a
            // #292 denial may persist until the next click — the
            // latch still blocks the teleport, so this residue
            // degrades, never breaks. Don't widen the gate.
            if movedHeldFocus {
                scheduleMoveSettle(
                    origin: state.workspaces.activeSpace,
                    priorFrontmost: priorFrontmost
                )
            }
        } else if movedHeldFocus {
            // Reached only when the active space has no member to
            // take over (else the neighbor branch fired) AND the
            // moved window held system key focus. It is now stashed
            // offscreen yet still key — orphaned — so hand focus to
            // the desktop, the state a bare empty-desktop click
            // leaves (#446). Keying on `lastFocused` (not the
            // emptied `from`) is the exact hazard: a move that did
            // NOT hold system focus never yields, and a #414
            // traveler / secondary-display window that DID hold it
            // is cleaned up wherever its origin was.
            desktopFocusYield?()
        }
        if !follow {
            // The follow branch retiled inside `followSwitch`
            // (a follow IS a space switch — same policy and force
            // contract).
            retile(animated: true)
        }
    }

    /// The one trade filing (#2509): `a` and `b`, in different
    /// Spaces, take each other's slot in one step, then each
    /// takes the side effects `fileMembership` owes a filing
    /// through the shared `settleFiling`. Only a window landing
    /// in the active Space moves the focus trackers; the other is
    /// its Space's focus for the next visit, whoever held focus,
    /// so the pair's order decides nothing.
    func fileTrade(_ a: WindowID, _ b: WindowID) {
        guard let from = state.workspaces.space(of: a),
            let to = state.workspaces.space(of: b),
            from != to
        else { return }
        let active = state.workspaces.activeSpace
        let filings = [(a, to, from), (b, from, to)].map {
            window,
            target,
            origin in
            (
                window: window,
                target: target,
                origin: origin,
                wasFloat: isEffectiveFloatForPlacement(window),
                takesFocus: target == active
            )
        }
        for filing in filings { state.stampUserFiling(filing.window) }
        state.workspaces.trade(a, b)
        for filing in filings {
            settleFiling(
                filing.window,
                into: filing.target,
                from: filing.origin,
                wasFloat: filing.wasFloat,
                takesFocus: filing.takesFocus
            )
        }
    }
}
