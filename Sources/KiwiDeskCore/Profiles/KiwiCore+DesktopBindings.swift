import Foundation

/// Why a sidecar rewrite wrote nothing — a case, never a
/// sentence (core-boundaries.md): a missing sidecar is never
/// minted, and one that no longer decodes is never overwritten
/// (`KiwiCore+ProfileEdit`'s rule).
public enum SidecarError: Error {
    case missing
    case unreadable
}

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
    /// The binding on the Desktop the MAIN screen is showing,
    /// under EITHER of that Desktop's keys (#1147) — the one
    /// resolver every reader of a Desktop binding takes.
    ///
    /// Asking under one key alone misses a binding that exists
    /// for the reading between a Desktop's first stamp and the
    /// re-key that follows it, which every upgrading user passes
    /// through once (architect review, 2026-09-04).
    public func mainDesktopBinding(
        in snapshot: DesktopSnapshot
    ) -> DesktopBinding? {
        guard let space = snapshot.mainCurrentSpace else {
            return nil
        }
        return snapshot.keys(of: space)
            .lazy
            .compactMap { self.desktopBindings[$0] }
            .first
    }

    /// The one rewrite of the stored binding table (#1392): `edit`
    /// runs over `bindings.json`'s OWN map, written through its one
    /// door (#2324). Throws `SidecarError` rather than minting a
    /// config or editing one that no longer decodes.
    public func rewriteSidecarBindings(
        _ edit: (inout [DesktopKey: DesktopBinding]) -> Void
    ) throws {
        guard guiConfigStore.exists else {
            throw SidecarError.missing
        }
        guard guiConfigStore.load() != nil else {
            throw SidecarError.unreadable
        }
        // `bindings.json` alone (#2324): a bindings edit writes no
        // `gui.json`. The runtime map follows the keys the edit
        // changed only where the structured apply set it from that
        // file; in a hybrid config it is init.lua's and stays so.
        let before = guiConfigStore.bindingsFile.load().profileBindings
        var map = before
        edit(&map)
        try guiConfigStore.saveBindings(map)
        guard isGuiManaged else { return }
        var changed = false
        for key in Set(before.keys).union(map.keys)
        where !DesktopBinding.sameStored(before[key], map[key]) {
            desktopBindings[key] = map[key]
            changed = true
        }
        // A rebound Desktop takes effect now, as it did when this
        // write went through a reload — unless the engine has not
        // started (a paused cold boot), which applies it at start.
        if changed, lua != nil {
            _ = applyDesktopBinding(in: NativeSpaces.desktopSnapshot())
        }
    }

    /// Re-keys and re-projects every binding this topology can
    /// name, rewriting the sidecar exactly when something moved.
    func reconcileDesktopBindings(in snapshot: DesktopSnapshot) {
        let screens = screenNamesByUUID()
        let result = Self.bindingMoves(
            in: desktopBindings,
            snapshot: snapshot,
            screens: screens
        )
        guard !result.moves.isEmpty || !result.drops.isEmpty else {
            return
        }
        for key in result.drops {
            onLog(
                "desktop bindings: dropped '\(key.stored)', "
                    + "superseded by the same Desktop's stamp"
            )
        }
        desktopBindings = Self.applying(result, to: desktopBindings)
        // The STORE's own value, never `loadGuiConfig()` — that
        // overlays live profile state (spaces, pins, modes,
        // settings), and persisting it here would materialize the
        // running layout into gui.json on a Desktop switch, with
        // no user Save. Neither of profiles.md's two ruled
        // profile writes is that (code review, 2026-09-04).
        guard isGuiManaged else { return }
        var live = GuiConfig()
        live.profileBindings =
            guiConfigStore.bindingsFile.load().profileBindings
        let sidecar = Self.bindingMoves(
            in: live.profileBindings,
            snapshot: snapshot,
            screens: screens
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
            // persistence alone, of this Mac's file alone (#2324).
            try guiConfigStore.saveBindings(live.profileBindings)
        } catch {
            onLog("desktop bindings: sidecar follow failed: \(error)")
        }
    }

    /// What each entry becomes in this topology, listed only
    /// where it CHANGES. A record whose Desktop the snapshot
    /// cannot name is dormant and is left exactly as it is —
    /// absence is never proof it is gone (#1147 ▸ #1230 contract,
    /// rule 3).
    /// Where each KEY of a per-Desktop map goes in this topology
    /// — generic over the value, so #1230's Space sets re-key
    /// through the same rule rather than a hand copy of it.
    ///
    /// The drop clause is why this is shared rather than copied:
    /// it took a correctness fix of its own, and a second hand
    /// copy would not have got it (architect review,
    /// 2026-09-04).
    static func keyMoves<Value>(
        in map: [DesktopKey: Value],
        snapshot: DesktopSnapshot
    ) -> (moves: [DesktopKey: DesktopKey], drops: Set<DesktopKey>) {
        var moves: [DesktopKey: DesktopKey] = [:]
        var drops: Set<DesktopKey> = []
        for key in map.keys {
            guard let space = snapshot.space(for: key),
                let now = snapshot.key(of: space.id), now != key
            else { continue }
            // A `.number` entry whose Desktop is ALREADY filed
            // under its stamp is removed rather than moved: both
            // name one Desktop, the stamped record is the one
            // this build wrote, and leaving the number entry in
            // place would shadow it the moment that Desktop lost
            // its stamp — a session where the write is refused,
            // or a macOS with no bridge — applying a stale
            // profile in its stead (code review, 2026-09-04).
            if map[now] != nil {
                drops.insert(key)
                continue
            }
            moves[key] = now
        }
        return (moves, drops)
    }

    /// The key moves above, plus the binding-specific projection
    /// refresh — the Mission Control number and the screen name
    /// a row is labelled with, which only this map carries.
    /// `screens` is the attached displays by UUID
    /// (`screenNamesByUUID`); a display it cannot name leaves the
    /// remembered screen as it was rather than blanking it.
    static func bindingMoves(
        in bindings: [DesktopKey: DesktopBinding],
        snapshot: DesktopSnapshot,
        screens: [String: String]
    ) -> (moves: [DesktopKey: BindingMove], drops: Set<DesktopKey>) {
        let keys = keyMoves(in: bindings, snapshot: snapshot)
        var moves: [DesktopKey: BindingMove] = [:]
        for (key, binding) in bindings where !keys.drops.contains(key) {
            let now = keys.moves[key] ?? key
            guard let space = snapshot.space(for: key),
                let number = snapshot.number(of: space.id)
            else { continue }
            var updated = binding
            updated.desktop = number
            if let name = screens[space.displayUUID] {
                updated.screen = name
            }
            guard now != key || updated != binding else { continue }
            moves[key] = BindingMove(key: now, binding: updated)
        }
        return (moves, keys.drops)
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

extension KiwiCore {
    /// The switch handler's binding apply, its window-rule sweep
    /// left to the switch's own folded `reconcileAll`, which runs
    /// right after the handler (`EventLoop.desktopChanged`) — a
    /// second sweep here, outside the fold, retiled once per
    /// window it folded (#2347). What the deferral costs is
    /// argued on `mayReconcileWindowRulesNow`.
    func applyBindingDeferringRuleSweep(
        in snapshot: DesktopSnapshot
    ) -> String? {
        let deferring = defersRuleSweepToSwitchPass
        defersRuleSweepToSwitchPass = true
        defer { defersRuleSweepToSwitchPass = deferring }
        return applyDesktopBinding(in: snapshot)
    }
}
