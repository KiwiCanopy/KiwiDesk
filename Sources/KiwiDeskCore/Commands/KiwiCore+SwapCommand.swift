import CoreGraphics
import Foundation

/// `swap` and `swap_here` (#2509). `swap` trades the focused
/// window's place: with its neighbour in a direction or with the
/// window an id names, focus going with it wherever it lands; two
/// ids trade those two and move no focus. `swap_here` keeps you
/// where you are: the named window takes your slot and the focus.
/// Windows in different Spaces trade places, each taking the
/// other's slot.

/// Where focus goes after a swap of `lead` with `partner`.
enum SwapFocus {
    /// It stays on `lead`, switching to the Space it lands in.
    case follows
    /// `lead` takes `partner`'s slot and the focus there.
    case staysHere
    /// It stays put, save that a window filed into the active
    /// Space takes its focus (#1518).
    case untouched
}

extension KiwiCore {
    func swapCommand(_ args: [JSONValue]) -> CommandResponse {
        let named = namesWindow("swap", args)
        if let raw = args.first?.stringValue,
            Direction(rawValue: raw) != nil
        {
            guard named else { return navigate(args, swapping: true) }
            // A named window steps from its own slot, in the Space
            // you are on, and moves no focus.
            switch commandTarget("swap", args) {
            case .refused(let response):
                return response
            case .window(let window):
                if let refusal = swapRefusal(window) { return refusal }
                guard
                    state.workspaces.space(of: window)
                        == state.workspaces.activeSpace
                else {
                    return .fail(
                        "window \(window.raw) is not in the Space you "
                            + "are on"
                    )
                }
                return navigate(args, swapping: true, origin: window)
            }
        }
        guard let first = args.first, first.numberValue != nil else {
            return .fail(
                "expected \(Direction.expectedList) or a window id"
            )
        }
        let given: WindowID
        switch windowTarget(first) {
        case .refused(let response): return response
        case .window(let id): given = id
        }
        switch commandTarget("swap", args) {
        case .refused(let response):
            return response
        case .window(let other):
            // Two ids name the pair and move no focus; one trades
            // the focused window, which focus follows.
            return named
                ? swapWindows(given, other, focus: .untouched)
                : swapWindows(other, given, focus: .follows)
        }
    }

    /// `swap_here <window>`: the focused window is read implied,
    /// under the #292 preflight, since the record takes no
    /// `.window` argument.
    func swapHereCommand(_ args: [JSONValue]) -> CommandResponse {
        guard let first = args.first, first.numberValue != nil else {
            return .fail("expected window id")
        }
        let incoming: WindowID
        switch windowTarget(first) {
        case .refused(let response): return response
        case .window(let id): incoming = id
        }
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        return swapWindows(incoming, focused, focus: .staysHere)
    }

    /// Swaps `lead` and `partner` — in place within one Space, a
    /// trade between two (#2509). Both must hold a layout slot:
    /// an effective float has none to trade and a native
    /// full-screen window keeps its own Space (#670).
    func swapWindows(
        _ lead: WindowID,
        _ partner: WindowID,
        focus: SwapFocus
    ) -> CommandResponse {
        guard lead != partner else {
            return .fail("cannot swap a window with itself")
        }
        for id in [lead, partner] {
            if let refusal = swapRefusal(id) { return refusal }
        }
        guard let home = state.workspaces.space(of: lead),
            let away = state.workspaces.space(of: partner)
        else {
            return .fail("window is in no Space")
        }
        guard home == away else {
            // Both sides asked before anything moves (#445), so a
            // refusal is the command's answer, not a silent no-op.
            if stickyMoveRefused(
                lead,
                to: away,
                landingOn: landingDisplay(of: away)
            )
                || stickyMoveRefused(
                    partner,
                    to: home,
                    landingOn: landingDisplay(of: home)
                )
            {
                return .fail("a sticky window cannot change Space")
            }
            moveWindow(
                lead,
                to: away,
                follow: focus == .follows,
                trading: partner
            )
            // The window a trade brings into the active Space sits
            // in an overflow pile at the slot it took, unstacked
            // (#150, #193); the gate keeps a trade between Spaces
            // nobody is on from restacking the active row. The
            // accepted cost: a trade into a stack cascade, or into
            // a Space another screen shows, arms no restore.
            let active = state.workspaces.activeSpace
            if active == home || active == away {
                scheduleScrollingZOrderRestoreIfOverflowing()
                scheduleTrackZOrderRestoreIfOverflowing()
            }
            return .ok()
        }
        guard let space = state.workspaces[home] else {
            return .fail("window is in no Space")
        }
        if refusesPileSwap(lead, partner, in: space) { return .ok() }
        commitSwap(lead, partner, in: space)
        if focus == .staysHere {
            focusWindow(lead, warp: true)
        }
        return .ok()
    }

    /// Why `id` holds no slot to swap, nil where it does: an
    /// effective float has none and a native full-screen window
    /// keeps its own Space (#670).
    private func swapRefusal(_ id: WindowID) -> CommandResponse? {
        if state.windows[id]?.isFullscreen == true {
            return .fail("window \(id.raw) is full screen")
        }
        if isEffectiveFloatForPlacement(id) {
            return .fail("window \(id.raw) is floating")
        }
        return nil
    }

    /// The directional swap's #438 refusal, asked both ways: a
    /// sticky window is never swapped into an overflow pile.
    private func refusesPileSwap(
        _ a: WindowID,
        _ b: WindowID,
        in space: Space
    ) -> Bool {
        // A run's hidden windows are no pile (#2235).
        let frames = shownSlots()
        let slots = state.effectiveTiledMembers(of: space)
            .compactMap { id -> (id: WindowID, frame: CGRect)? in
                frames[id].map { (id, $0) }
            }
        return refuseStickyIntoPile(a, target: b, among: slots)
            || refuseStickyIntoPile(b, target: a, among: slots)
    }
}
