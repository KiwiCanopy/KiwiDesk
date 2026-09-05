import Foundation

/// The KiwiDesk Space an explicit `space:` target on a Desktop
/// move names for a window leaving for a HIDDEN Desktop (#1150).
/// Recorded at the command and paid at the window's DEPARTURE:
/// the destroy fold files the window's remembered Space as it
/// leaves, and the pending name replaces that record
/// (`StateCoordinator.redirectDeparture`), so the arrival's
/// ordinary remembered-space rule lands it there. Never an eager
/// membership write — the window joins KiwiDesk state at the
/// reveal, and an eager write races the reveal reconcile it
/// would then fight (#890 ▸ arrival semantics). Per window, so
/// two moves in flight keep their own names; bounded like the
/// follow's debt, because a move the bridge accepted but never
/// applied produces no departure, and an unpaid name must not
/// attach to a close minutes later. A third arrival-shaped
/// ledger beside `FollowFocusIntent`'s two instances, minted
/// rather than a third instance because it carries a Space, not
/// a focus.
@MainActor
final class PendingSpaceAssignment {
    /// How long a recorded name stays claimable — the follow's
    /// bound, for the same reason (#1007).
    static let drainWindow: TimeInterval =
        FollowFocusIntent.drainWindow

    private var pending: [WindowID: (space: SpaceID, at: Date)] =
        [:]

    var isEmpty: Bool { pending.isEmpty }

    /// Names the Space `id` joins when it departs.
    func record(
        _ id: WindowID,
        space: SpaceID,
        at now: Date = Date()
    ) {
        pending[id] = (space, now)
    }

    /// The name owed to `id`, claimed once at its departure; nil
    /// when none was recorded or the record expired unpaid.
    func claim(
        _ id: WindowID,
        at now: Date = Date()
    ) -> SpaceID? {
        guard let entry = pending.removeValue(forKey: id) else {
            return nil
        }
        guard now.timeIntervalSince(entry.at) < Self.drainWindow
        else { return nil }
        return entry.space
    }

    /// Follows a native-tab re-key (#308).
    func rekey(old: WindowID, new: WindowID) {
        guard let entry = pending.removeValue(forKey: old) else {
            return
        }
        pending[new] = entry
    }
}
