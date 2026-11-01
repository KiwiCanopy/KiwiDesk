import CoreGraphics
import Foundation

/// The pocket's pure transitions (#2446, #2678). A pocketed window
/// is KNOWN in its slot and tracked in `windows`, never a member of
/// a Space: a missed `space.windows` reader then leaves it hidden
/// rather than drawing it. Out, it is a float with the global
/// sticky scope, so every sticky derivation carries it. `pocket` is
/// in put-in order: the last pocketed slot came in most recently.
extension StateCoordinator {
    /// The phase of `id`'s slot, or nil for a window not marked.
    public func pocketPhase(of id: WindowID) -> PocketSlot.Phase? {
        pocketSlot(of: id)?.phase
    }

    /// `id`'s slot, or nil for a window not marked.
    public func pocketSlot(of id: WindowID) -> PocketSlot? {
        pocket.first { $0.window == id }
    }

    /// The screen pocketed windows wait on: the active Space's.
    /// The park and the Desktop carry both read it.
    var pocketHomeDisplay: DisplayID? {
        workspaces.activeSpace.flatMap { workspaces.display(of: $0) }
    }

    /// The app whose Pocket key owns `id`'s slot (#2612), nil for
    /// a window of the general list or none.
    public func pocketKeyOwner(of id: WindowID) -> String? {
        pocketSlot(of: id)?.keyedApp
    }

    /// The general list `pocket` steps through and the capacity
    /// counts: every slot no app's key owns (#2612 ▸ 5).
    var generalPocket: [PocketSlot] {
        pocket.filter { $0.keyedApp == nil }
    }

    /// The slot `bundleID`'s Pocket key owns.
    func pocketSlot(ownedBy bundleID: String) -> PocketSlot? {
        pocket.first { $0.keyedApp == bundleID }
    }

    /// Whether `id` is in the pocket (not out of it).
    public func isPocketed(_ id: WindowID) -> Bool {
        pocketPhase(of: id) == .pocketed
    }

    /// The windows in the pocket, in put-in order.
    public var pocketedWindows: [WindowID] {
        pocket.filter { $0.phase == .pocketed }.map(\.window)
    }

    /// The window `pocket` takes out next: the general list's
    /// one put in last.
    public var pocketTakeOutNext: WindowID? {
        generalPocket.last { $0.phase == .pocketed }?.window
    }

    /// The out window `pocket` puts back next (#2678): `focused`
    /// where it is one, else the one focused last by the honored
    /// focus recency (#1840), which a take-out's own focus report
    /// stamps. Only a tracked window qualifies; a hidden app's
    /// comes back by its unhide.
    func pocketPutBackNext(focused: WindowID?) -> WindowID? {
        let out = generalPocket.filter {
            $0.phase == .out && windows[$0.window] != nil
        }.map(\.window)
        if let focused, out.contains(focused) { return focused }
        return out.max {
            focusRecencyRank(of: $0) < focusRecencyRank(of: $1)
        }
    }

    /// Whether `toggle_pocket_window` may mark another window under
    /// `capacity` (#2678): One window takes a mark only while the
    /// general list is empty, Several always; a keyed slot never
    /// counts (#2612 ▸ 5). `pocket`'s own mark asks for an empty
    /// general list.
    func pocketAcceptsMark(_ capacity: PocketCapacity) -> Bool {
        capacity == .several || generalPocket.isEmpty
    }

    /// Puts the out window `id` in the pocket: floating, no sticky
    /// scope, filed in no Space, last in put-in order. A slot fills
    /// only through `markPocketWindow` (#2675), so any other window
    /// is refused.
    mutating func pocketWindow(_ id: WindowID) {
        guard let index = pocketIndex(of: id),
            pocket[index].phase == .out, windows[id] != nil
        else { return }
        windows.setFloating(id, true)
        windows.setSticky(id, .none)
        userFloated.remove(id)
        workspaces.remove(id)
        var slot = pocket.remove(at: index)
        slot.phase = .pocketed
        slot.cameFrom = nil
        pocket.append(slot)
    }

    /// Marks `id` a pocket window where it is (#2675): out, its
    /// membership kept, never pocketed yet. False for an untracked
    /// or already marked window; the caller asks
    /// `pocketAcceptsMark` first.
    @discardableResult
    mutating func markPocketWindow(
        _ id: WindowID,
        owner: String? = nil
    ) -> Bool {
        guard pocketIndex(of: id) == nil, windows[id] != nil
        else { return false }
        userFloated.remove(id)
        pocket.append(
            PocketSlot(
                window: id,
                pid: windows[id]?.pid,
                phase: .out,
                owner: owner
            )
        )
        markPocketOut(id, cameFrom: nil)
        return true
    }

    /// Empties `id`'s slot, leaving the window the user's plain
    /// float with no sticky scope; filing it is the caller's. The
    /// window, where it is still tracked.
    @discardableResult
    mutating func releasePocketWindow(_ id: WindowID) -> WindowID? {
        guard pocketIndex(of: id) != nil else { return nil }
        emptyPocket(id)
        guard windows[id] != nil else { return nil }
        windows.setSticky(id, .none)
        setFloating(id, true)
        return id
    }

    /// Marks `id`'s slot out: floating and on every Space.
    /// Its filing is the caller's, through `fileMembership`.
    mutating func markPocketOut(_ id: WindowID, cameFrom: WindowID?) {
        guard let index = pocketIndex(of: id), windows[id] != nil
        else { return }
        windows.setFloating(id, true)
        windows.setSticky(id, .global)
        pocket[index].phase = .out
        pocket[index].cameFrom = cameFrom == id ? nil : cameFrom
    }

    /// Remembers where `id` sits out of the pocket, on the screen
    /// whose fingerprint is `screen`.
    mutating func rememberPocketFrame(
        _ frame: CGRect,
        of id: WindowID,
        on screen: String
    ) {
        guard let index = pocketIndex(of: id) else { return }
        pocket[index].frames[screen] = frame
    }

    /// The slots follow a native-tab re-key (#308).
    mutating func rekeyPocket(_ old: WindowID, to new: WindowID) {
        for index in pocket.indices {
            if pocket[index].window == old { pocket[index].window = new }
            if pocket[index].cameFrom == old {
                pocket[index].cameFrom = new
            }
        }
    }

    /// Empties `id`'s slot: an out window stays an ordinary float on
    /// the Space it is in; a pocketed one is left for the caller to
    /// file.
    mutating func emptyPocket(_ id: WindowID) {
        guard let index = pocketIndex(of: id) else { return }
        if pocket[index].phase == .out { windows.setSticky(id, .none) }
        pocket.remove(at: index)
    }

    /// `id` re-tracked (#913's unhide, a boot scan, a replay): a
    /// pocketed one is kept out of every Space, and either phase
    /// keeps the flags the AX snapshot does not carry. True where
    /// the create fold must file nothing.
    mutating func readoptPocketWindow(_ id: WindowID) -> Bool {
        guard let phase = pocketPhase(of: id) else { return false }
        windows.setFloating(id, true)
        windows.setSticky(id, phase == .out ? .global : .none)
        return phase == .pocketed
    }

    private func pocketIndex(of id: WindowID) -> Int? {
        pocket.firstIndex { $0.window == id }
    }
}
