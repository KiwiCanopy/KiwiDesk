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
        let result = Self.bindingMoves(
            in: desktopBindings,
            snapshot: snapshot
        )
        guard !result.moves.isEmpty || !result.drops.isEmpty else {
            return
        }
        desktopBindings = Self.applying(result, to: desktopBindings)
        // The STORE's own value, never `loadGuiConfig()` — that
        // overlays live profile state (spaces, pins, modes,
        // settings), and persisting it here would materialize the
        // running layout into gui.json on a Desktop switch, with
        // no user Save. Neither of profiles.md's two ruled
        // profile writes is that (code review, 2026-09-04).
        guard isGuiManaged, var live = guiConfigStore.load() else {
            return
        }
        let sidecar = Self.bindingMoves(
            in: live.profileBindings,
            snapshot: snapshot
        )
        guard !sidecar.moves.isEmpty || !sidecar.drops.isEmpty
        else { return }
        live.profileBindings = Self.applying(
            sidecar,
            to: live.profileBindings
        )
        do {
            // The STORE, never `saveGuiConfig` — that reloads the
            // whole config, and this runs inside
            // `stampedDesktopSnapshot()` at the TOP of the switch
            // handler. A reload there rebuilds the Lua VM, clears
            // the very map just re-keyed and takes a SECOND live
            // snapshot mid-switch, which is the one-reading rule
            // (#888) broken by the lane that restates it. The
            // re-key is already applied in memory; this is
            // persistence alone.
            try guiConfigStore.save(live)
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
    ) -> (moves: [DesktopKey: BindingMove], drops: Set<DesktopKey>) {
        var moves: [DesktopKey: BindingMove] = [:]
        var drops: Set<DesktopKey> = []
        for (key, binding) in bindings {
            guard let space = snapshot.space(for: key),
                let now = snapshot.key(of: space.id),
                let number = snapshot.number(of: space.id)
            else { continue }
            // A `.number` entry whose Desktop is ALREADY filed
            // under its stamp is removed rather than moved: both
            // name one Desktop, the stamped record is the one
            // this build wrote, and leaving the number entry in
            // place would shadow it the moment that Desktop lost
            // its stamp — a session where the write is refused,
            // or a macOS with no bridge — applying a stale
            // profile in its stead (code review, 2026-09-04).
            if now != key, bindings[now] != nil {
                drops.insert(key)
                continue
            }
            var updated = binding
            updated.desktop = number
            updated.display = space.displayUUID
            guard now != key || updated != binding else { continue }
            moves[key] = BindingMove(key: now, binding: updated)
        }
        return (moves, drops)
    }

    /// Applies the moves, removing a key only where it actually
    /// moved — a projection refresh rewrites in place.
    static func applying(
        _ result: (
            moves: [DesktopKey: BindingMove],
            drops: Set<DesktopKey>
        ),
        to bindings: [DesktopKey: DesktopBinding]
    ) -> [DesktopKey: DesktopBinding] {
        var out = bindings
        for key in result.drops { out[key] = nil }
        for (from, move) in result.moves {
            if move.key != from { out[from] = nil }
            out[move.key] = move.binding
        }
        return out
    }
}
