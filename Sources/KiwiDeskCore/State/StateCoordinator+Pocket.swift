import CoreGraphics
import Foundation

/// The pocket's pure transitions (#2446). A pocketed window is
/// KNOWN in the slot and tracked in `windows`, never a member of
/// a Space: a missed `space.windows` reader then leaves it hidden
/// rather than drawing it. Out, it is a float with the global
/// sticky scope, so every sticky derivation carries it.
extension StateCoordinator {
    /// The slot's phase for `id`, or nil for any other window.
    public func pocketPhase(of id: WindowID) -> PocketSlot.Phase? {
        pocket?.window == id ? pocket?.phase : nil
    }

    /// The pocketed window, while one is in the pocket.
    public var pocketedWindow: WindowID? {
        pocket?.phase == .pocketed ? pocket?.window : nil
    }

    /// Puts `id` in the pocket: floating, no sticky scope, filed in
    /// no Space. A window already the slot's keeps its frames.
    mutating func pocketWindow(_ id: WindowID) {
        guard windows[id] != nil else { return }
        let frames = pocket?.window == id ? pocket?.frames ?? [:] : [:]
        windows.setFloating(id, true)
        windows.setSticky(id, .none)
        userFloated.remove(id)
        workspaces.remove(id)
        pocket = PocketSlot(window: id, phase: .pocketed, frames: frames)
    }

    /// Marks the slot's window out: floating and on every Space.
    /// Its filing is the caller's, through `fileMembership`.
    mutating func markPocketOut(cameFrom: WindowID?) {
        guard let id = pocket?.window, windows[id] != nil else { return }
        windows.setFloating(id, true)
        windows.setSticky(id, .global)
        pocket?.phase = .out
        pocket?.cameFrom = cameFrom == id ? nil : cameFrom
    }

    /// Remembers where the slot's window sits out of the pocket, on
    /// the screen whose fingerprint is `screen`.
    mutating func rememberPocketFrame(_ frame: CGRect, on screen: String) {
        pocket?.frames[screen] = frame
    }

    /// The slot follows a native-tab re-key (#308).
    mutating func rekeyPocket(_ old: WindowID, to new: WindowID) {
        if pocket?.window == old { pocket?.window = new }
        if pocket?.cameFrom == old { pocket?.cameFrom = new }
    }

    /// Empties the pocket: an out window stays an ordinary float on
    /// the Space it is in; a pocketed one is left for the caller to
    /// file.
    mutating func emptyPocket() {
        guard let id = pocket?.window else { return }
        if pocket?.phase == .out { windows.setSticky(id, .none) }
        pocket = nil
    }

    /// The slot's window re-tracked (#913's unhide, a boot scan, a
    /// replay): a pocketed one is kept out of every Space, and either
    /// phase keeps the flags the AX snapshot does not carry. True
    /// where the create fold must file nothing.
    mutating func readoptPocketWindow(_ id: WindowID) -> Bool {
        guard let phase = pocketPhase(of: id) else { return false }
        windows.setFloating(id, true)
        windows.setSticky(id, phase == .out ? .global : .none)
        return phase == .pocketed
    }
}
