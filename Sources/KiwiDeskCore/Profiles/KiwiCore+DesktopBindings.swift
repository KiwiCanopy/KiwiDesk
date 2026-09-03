import Foundation

/// The two crossings a Desktop binding owes, both of which END
/// (#1147, AGENTS.md §5).
///
/// A binding filed under `.number(n)` — written before this
/// Desktop was stamped, or by a build that had no stamps — moves
/// to that Desktop's identity the first time the topology can
/// name it. And the `desktop` a record carries is a PROJECTION:
/// the number a row is labelled with, refreshed whenever the
/// Desktop it names has moved.
///
/// Both are applied to the sidecar's OWN map rather than by
/// adopting the runtime one — in a hybrid config the runtime map
/// also holds init.lua's bindings, and materializing those into
/// gui.json would resurrect a binding whose Lua line the user
/// then deleted (`KiwiCore+ProfileRename`'s rule).
/// Where one binding entry moves to, and what it says once it
/// gets there.
struct BindingMove {
    let key: DesktopKey
    let binding: DesktopBinding
}

extension KiwiCore {
    /// Re-keys and re-projects every binding this topology can
    /// name, rewriting the sidecar exactly when something moved.
    func reconcileDesktopBindings(in snapshot: DesktopSnapshot) {
        let moves = Self.bindingMoves(
            in: desktopBindings,
            snapshot: snapshot
        )
        guard !moves.isEmpty else { return }
        desktopBindings = Self.applying(moves, to: desktopBindings)
        guard isGuiManaged, guiConfigStore.load() != nil else {
            return
        }
        var live = loadGuiConfig()
        let sidecar = Self.bindingMoves(
            in: live.profileBindings,
            snapshot: snapshot
        )
        guard !sidecar.isEmpty else { return }
        live.profileBindings = Self.applying(
            sidecar,
            to: live.profileBindings
        )
        do {
            try saveGuiConfig(live)
        } catch {
            onLog("desktop bindings: sidecar follow failed: \(error)")
        }
    }

    /// What each entry becomes in this topology, listed only
    /// where it CHANGES. A record whose Desktop the snapshot
    /// cannot name is dormant and is left exactly as it is —
    /// absence is never proof it is gone (#1147 ▸ #1230 contract,
    /// rule 3).
    static func bindingMoves(
        in bindings: [DesktopKey: DesktopBinding],
        snapshot: DesktopSnapshot
    ) -> [DesktopKey: BindingMove] {
        var moves: [DesktopKey: BindingMove] = [:]
        for (key, binding) in bindings {
            guard let space = snapshot.space(for: key),
                let now = snapshot.key(of: space.id),
                let number = snapshot.number(of: space.id)
            else { continue }
            // A `.number` entry moving onto a stamp another entry
            // already holds is DROPPED rather than clobbering it:
            // both name the same Desktop, and the stamped record
            // is the one this build wrote.
            if now != key, bindings[now] != nil { continue }
            var updated = binding
            updated.desktop = number
            updated.display = space.displayUUID
            guard now != key || updated != binding else { continue }
            moves[key] = BindingMove(key: now, binding: updated)
        }
        return moves
    }

    /// Applies the moves, removing a key only where it actually
    /// moved — a projection refresh rewrites in place.
    static func applying(
        _ moves: [DesktopKey: BindingMove],
        to bindings: [DesktopKey: DesktopBinding]
    ) -> [DesktopKey: DesktopBinding] {
        var out = bindings
        for (from, move) in moves {
            if move.key != from { out[from] = nil }
            out[move.key] = move.binding
        }
        return out
    }
}
