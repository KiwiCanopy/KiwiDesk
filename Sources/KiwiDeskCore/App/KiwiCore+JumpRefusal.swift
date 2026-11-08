import Foundation

/// Why a KiwiHub pick would refuse a row (#2885 ▸ refusals shown in
/// the row): the verdicts its rows are drawn by and its presses are
/// asked at press time, each read off the verb's own gates, so a row
/// and the verb never disagree. A slice that admits a row kind this
/// one refuses drops its case here, where both read it.
extension KiwiCore {
    /// Why Swap here from `display` would not trade `target`, read
    /// now; nil where it trades or where only the verb can tell.
    public func swapRefusal(
        _ target: JumpEntry.Target,
        on display: DisplayID? = nil
    ) -> JumpSwapBlock? {
        let partner = jumpSwapPartner(in: moveHereSpace(on: display))
        // A row the verb cannot see answers yours first; a tracked
        // row takes the verb's one verdict, as its row does.
        let yours = yoursSwapBlock(partner)
        guard case .window(let id) = target else {
            return yours ?? .hiddenApp
        }
        if let away = state.awayWindows[id] {
            let desktops = desktopMemory.readDesktops()
            if let yours { return yours }
            if awayIsFullScreen(away, in: desktops) { return .fullScreen }
            return .otherDesktop(desktops.number(of: away.nativeSpace))
        }
        if state.minimizeOrder.contains(where: { $0.id == id }) {
            return yours ?? .minimized
        }
        guard state.windows[id] != nil else { return nil }
        return jumpSwapBlock(id, partner: partner)
    }

    /// Why Move here from `display` would refuse `target`, read now.
    public func moveHereRefusal(
        _ target: JumpEntry.Target,
        on display: DisplayID? = nil
    ) -> JumpMoveBlock? {
        guard case .window(let id) = target else { return nil }
        if let away = state.awayWindows[id] {
            let desktops = desktopMemory.readDesktops()
            return awayIsFullScreen(away, in: desktops) ? .fullScreen : nil
        }
        guard let window = state.windows[id],
            let here = moveHereSpace(on: display)
        else { return nil }
        return jumpMoveBlock(window, into: here)
    }

    /// Your side's block for a row the verb cannot see — away,
    /// minimized or a hidden app — read before the row's own: a
    /// full-screen window of yours trades with nothing (#2930).
    func yoursSwapBlock(_ partner: WindowID?) -> JumpSwapBlock? {
        guard let partner, state.windows[partner]?.isFullscreen == true
        else { return nil }
        return .yoursFullScreen
    }

    /// Whether away `window` sits on a native full-screen Space,
    /// its own macOS Space (#670, #2930), rather than a Desktop.
    func awayIsFullScreen(
        _ window: AwayWindow,
        in desktops: DesktopSnapshot
    ) -> Bool {
        isFullScreenHost(window.nativeSpace, in: desktops.spaces)
    }

    /// Whether `space` is a native full-screen Space rather than a
    /// Desktop — the one verdict the away row, Jump's arm and the
    /// element it keeps share (#2939).
    func isFullScreenHost(
        _ space: SkyLight.SpaceID,
        in spaces: [NativeSpace]
    ) -> Bool {
        !NativeSpaces.isUserSpace(space, in: spaces)
    }

    /// Why a Swap here would not trade tracked `window` with
    /// `partner`, by the verb's one verdict (`SwapBlock`), named for
    /// the side that blocks; nil where it trades.
    func jumpSwapBlock(
        _ window: WindowID,
        partner: WindowID?
    ) -> JumpSwapBlock? {
        guard let partner else { return .nothingHere }
        guard let block = swapBlock(window, partner) else { return nil }
        let theirs: Bool
        switch block {
        case .sameWindow: return .yours
        case .unfiled(let id): theirs = id == window
        case .fullScreen(let id), .floating(let id): theirs = id == window
        case .sticky(let id, _): theirs = id == window
        }
        switch (block, theirs) {
        case (.unfiled, true):
            return state.isPocketed(window) ? .pocketed : .unfiled
        case (.unfiled, false): return .nothingHere
        case (.fullScreen, true): return .fullScreen
        case (.fullScreen, false): return .yoursFullScreen
        case (.floating, true): return .floating
        case (.floating, false): return .yoursFloating
        case (.sticky, true): return .sticky
        case (.sticky, false): return .yoursSticky
        case (.sameWindow, _): return .yours
        }
    }

    /// What Move here does with `window` before it moves it: the
    /// one verdict `moveTracked` refuses by and a row is drawn by.
    enum MoveHereVerdict: Equatable {
        /// Full screen: its own macOS Space (#670).
        case fullScreen
        /// The sticky gate keeps it where it is; `scope` names the
        /// gate's pill.
        case sticky(StickyScope)
        /// A ∞ window already renders here: it is only focused.
        case focusOnly
    }

    /// Nil where Move here moves `window` into `here`, or finds it
    /// there already.
    func moveHereVerdict(
        _ window: ManagedWindow,
        into here: SpaceID
    ) -> MoveHereVerdict? {
        if window.isFullscreen { return .fullScreen }
        guard let block = stickyMoveBlock(window.id, to: here) else {
            return nil
        }
        return block == .global && window.stickyScope == .global
            ? .focusOnly : .sticky(block)
    }

    /// Move here's refusal of `window`, nil where it moves it, finds
    /// it here, takes it out of the pocket or only focuses it.
    func jumpMoveBlock(
        _ window: ManagedWindow,
        into here: SpaceID
    ) -> JumpMoveBlock? {
        // A pocketed window comes out instead (#2446).
        guard !state.isPocketed(window.id) else { return nil }
        switch moveHereVerdict(window, into: here) {
        case .fullScreen: return .fullScreen
        case .sticky: return .sticky
        case .focusOnly, nil: return nil
        }
    }
}
