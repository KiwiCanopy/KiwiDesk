import Foundation

/// The focused window's Desktop-reach override wire values
/// (`override_sticky_reach`, #1145). `auto` clears back to the
/// global `sticky.desktop_reach` toggle.
public enum StickyReachOverride: String, CaseIterable, Sendable {
    case on
    case off
    case auto
}

/// The owned-state ledger behind sticky Desktop reach (#1145):
/// `CopySpacesForWindows` never reports a second membership
/// (#889 item 5), so asserted memberships are tracked here and
/// reconciled by diff. `KiwiCore+StickyReach.swift` is the one
/// machine driving it.
struct StickyReach {
    /// Space memberships this app holds asserted, per window —
    /// plus, after a home migrated INTO an asserted space, that
    /// retained home itself (see `reconcile`): such an entry is
    /// kept so the membership stays reclaimable, at the cost of
    /// one home resolution per refresh pass for as long as the
    /// window lives.
    private(set) var asserted: [WindowID: Set<SkyLight.SpaceID>] = [:]

    /// Reconciles the ledger against `wanted`, dispatching adds
    /// and removals through the handed closures and folding
    /// their outcomes back in:
    /// - only an ACCEPTED add is recorded — a refused one
    ///   re-issues on the next refresh;
    /// - a refused removal stays asserted, for the same reason;
    /// - a removal inside `homes` — the window's own
    ///   WindowServer memberships — is never dispatched AND
    ///   stays asserted, so a home that migrated into an
    ///   asserted space is still reclaimable if it later
    ///   migrates away;
    /// - a window absent from `wanted` retires through the same
    ///   arms, which is how unsticky, the toggle, an override
    ///   and a re-key all take effect (#1145).
    mutating func reconcile(
        wanted: [WindowID: Set<SkyLight.SpaceID>],
        homes: [WindowID: Set<SkyLight.SpaceID>],
        add: (WindowID, Set<SkyLight.SpaceID>) -> Bool,
        remove: (WindowID, Set<SkyLight.SpaceID>) -> Bool
    ) {
        for (id, want) in wanted {
            reconcileWindow(
                id,
                want: want,
                home: homes[id] ?? [],
                add: add,
                remove: remove
            )
        }
        for (id, _) in asserted where wanted[id] == nil {
            reconcileWindow(
                id,
                want: [],
                home: homes[id] ?? [],
                add: add,
                remove: remove
            )
        }
    }

    private mutating func reconcileWindow(
        _ id: WindowID,
        want: Set<SkyLight.SpaceID>,
        home: Set<SkyLight.SpaceID>,
        add: (WindowID, Set<SkyLight.SpaceID>) -> Bool,
        remove: (WindowID, Set<SkyLight.SpaceID>) -> Bool
    ) {
        var held = asserted[id] ?? []
        let toAdd = want.subtracting(held).subtracting(home)
        if !toAdd.isEmpty, add(id, toAdd) {
            held.formUnion(toAdd)
        }
        let toDrop = held.subtracting(want).subtracting(home)
        if !toDrop.isEmpty, remove(id, toDrop) {
            held.subtract(toDrop)
        }
        asserted[id] = held.isEmpty ? nil : held
    }

    /// Drops a gone window's ledger without dispatch — the
    /// WindowServer already forgot the window with its
    /// memberships.
    mutating func forget(_ id: WindowID) {
        asserted[id] = nil
    }

    /// The Desktops a sticky window is WANTED on: its scope's
    /// user Desktops. The caller excludes the window's own
    /// memberships via `reconcile`'s `homes`.
    static func wantedSpaces(
        scope: StickyScope,
        homeDisplayUUID: String?,
        in spaces: [NativeSpace]
    ) -> Set<SkyLight.SpaceID> {
        let pool: [NativeSpace]
        switch scope {
        case .none:
            return []
        case .global:
            pool = spaces.filter(\.isUser)
        case .display:
            // Shared-Spaces mode carries ONE display record
            // whose identifier is not a screen UUID (the shape
            // `desktopSnapshot()`'s authority falls back on) —
            // one list means 📌 and ∞ coincide.
            let uuids = Set(spaces.map(\.displayUUID))
            if uuids.count <= 1 {
                pool = spaces.filter(\.isUser)
            } else {
                guard let homeDisplayUUID else { return [] }
                pool = spaces.filter {
                    $0.isUser
                        && $0.displayUUID == homeDisplayUUID
                }
            }
        }
        return Set(pool.map(\.id))
    }
}
