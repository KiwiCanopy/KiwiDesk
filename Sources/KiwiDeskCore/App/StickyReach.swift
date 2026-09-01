import Foundation

/// The focused window's Desktop-reach override wire values
/// (`override_sticky_reach`, #1145). `auto` clears back to the
/// global `sticky.desktop_reach` toggle.
public enum StickyReachOverride: String, CaseIterable, Sendable {
    case on
    case off
    case auto
}

/// The owned-state ledger behind sticky Desktop reach (#1145).
///
/// `AddWindowsToSpacesOperation` gives a sticky window real
/// multi-Desktop presence, but no query can verify or undo it:
/// `CopySpacesForWindows` never reports a second membership
/// (#889 item 5), so what this app asserted is tracked HERE and
/// reconciled by diff — os-private-apis.md's verify-by-owned-
/// state rule. Pure bookkeeping: the caller derives what is
/// WANTED and dispatches what `reconcile` returns
/// (`KiwiCore+StickyReach.swift`).
struct StickyReach {
    /// Space memberships this app has asserted, per window.
    private(set) var asserted: [WindowID: Set<SkyLight.SpaceID>] = [:]

    /// One reconcile's dispatch work.
    struct Step: Equatable {
        var add: [WindowID: Set<SkyLight.SpaceID>] = [:]
        var remove: [WindowID: Set<SkyLight.SpaceID>] = [:]
        var isEmpty: Bool { add.isEmpty && remove.isEmpty }
    }

    /// Diffs `wanted` against the ledger: additions for what is
    /// wanted and not asserted, removals for what is asserted
    /// and no longer wanted — a window absent from `wanted`
    /// retires wholesale, which is how unsticky, a narrowed
    /// scope, an override and the global toggle all take effect
    /// through one door. The ledger is updated as if the step
    /// succeeds: performed is not applied and nothing can
    /// re-query (#889), so believing our own asks — and
    /// re-asserting idempotently on every refresh — is the
    /// design, not an oversight.
    mutating func reconcile(
        wanted: [WindowID: Set<SkyLight.SpaceID>]
    ) -> Step {
        var step = Step()
        for (id, spaces) in wanted {
            let have = asserted[id] ?? []
            let add = spaces.subtracting(have)
            let drop = have.subtracting(spaces)
            if !add.isEmpty { step.add[id] = add }
            if !drop.isEmpty { step.remove[id] = drop }
            asserted[id] = spaces.isEmpty ? nil : spaces
        }
        for (id, have) in asserted where wanted[id] == nil {
            if !have.isEmpty { step.remove[id] = have }
            asserted[id] = nil
        }
        return step
    }

    /// Drops a gone window's ledger without dispatch — the
    /// WindowServer already forgot the window with its
    /// memberships, and a removal aimed at a dead id is work
    /// for nothing.
    mutating func forget(_ id: WindowID) {
        asserted[id] = nil
    }

    /// Every membership the ledger still holds, for teardown:
    /// quitting must not leave windows parked on every Desktop
    /// with nothing left to undo it.
    mutating func drainAll() -> [WindowID: Set<SkyLight.SpaceID>] {
        defer { asserted = [:] }
        return asserted
    }

    /// The Desktops a sticky window is WANTED on (#1145): its
    /// scope's user Desktops, minus the space the window
    /// actually lives on — `exclude` — because that membership
    /// is the WindowServer's, not ours, and a removal that
    /// named it would take the window off its own Desktop.
    static func wantedSpaces(
        scope: StickyScope,
        homeDisplayUUID: String?,
        excluding exclude: Set<SkyLight.SpaceID>,
        in spaces: [NativeSpace]
    ) -> Set<SkyLight.SpaceID> {
        let pool: [NativeSpace]
        switch scope {
        case .none:
            return []
        case .global:
            pool = spaces.filter(\.isUser)
        case .display:
            guard let homeDisplayUUID else { return [] }
            pool = spaces.filter {
                $0.isUser && $0.displayUUID == homeDisplayUUID
            }
        }
        return Set(pool.map(\.id)).subtracting(exclude)
    }
}
