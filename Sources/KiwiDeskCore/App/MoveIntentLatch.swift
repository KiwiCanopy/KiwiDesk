import Foundation

/// Windows just moved to another space WITHOUT follow, stamped
/// with the move time (#482/#483).
///
/// A plain `move_to_space` refocuses the origin through the same
/// cooperative raise a space switch uses, and the OS may quietly
/// drop that activate (#463). The MOVED window then keeps OS key
/// focus, its app re-reports it as AX-focused, and the deferred
/// focus-follow (#22) would "follow" that re-report — teleporting
/// the user to the target space or display the move explicitly
/// chose not to visit. `scheduleFocusFollow` consults this latch
/// and drops re-reports for a freshly moved window instead.
///
/// Purely age-compared and pruned on write, never consumed — the
/// `selfRaiseStamps` pattern, sized the same way: Electron/WebKit
/// apps answer AX lazily (100–300 ms), so the re-report can trail
/// the move by several hundred ms; beyond ~1 s a focus report for
/// the moved window is a user action (a deliberate click on it)
/// and must follow normally.
///
/// Deliberately honor-except-follow, NOT a revert-and-return
/// sibling of the activation-re-report distrust in
/// `handleWindowFocused`: a latched report may be a genuine
/// click the latch cannot tell from the echo, so state focus,
/// the ring, and the focus-change emit are all still honored —
/// only the space-follow is suppressed. Folding this into the
/// distrust ladder with revert semantics would eat a real
/// click's focus entirely, a worse residue than "no follow
/// once".
@MainActor
final class MoveIntentLatch {
    /// Beyond this age a stamp no longer suppresses the follow.
    /// The accepted trade: a genuine click on the just-moved
    /// window inside the window is not followed once — the next
    /// focus report follows normally (accepted-limitations row).
    static let window: TimeInterval = 1.0

    private var stamps: [WindowID: Date] = [:]

    /// Records a no-follow move of `id`, pruning expired entries
    /// so stamps for windows that never re-report cannot pile up.
    func stamp(_ id: WindowID, at now: Date = Date()) {
        stamps = stamps.filter {
            now.timeIntervalSince($0.value) < Self.window
        }
        stamps[id] = now
    }

    /// Whether a focus re-report for `id` arrives inside the
    /// suppression window of a no-follow move.
    func isLatched(_ id: WindowID, at now: Date = Date()) -> Bool {
        guard let stamp = stamps[id] else { return false }
        return now.timeIntervalSince(stamp) < Self.window
    }

    /// Retargets a stamp on a native-tab rekey (#308): the moved
    /// window still holds OS key focus in the exact hazard this
    /// latch guards, so a tab-switch chord inside the window
    /// mints a fresh id whose re-report would otherwise arrive
    /// unlatched — the teleport reintroduced on one path. Called
    /// from the `.windowRekeyed` bookkeeping transfer. No prune
    /// here by design — pruning rides `stamp`.
    func rekey(old: WindowID, new: WindowID) {
        guard let stamp = stamps.removeValue(forKey: old) else {
            return
        }
        stamps[new] = stamp
    }
}
