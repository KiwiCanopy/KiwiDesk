import Foundation

/// Sticky Desktop reach (#1145): a sticky window is genuinely
/// present across macOS Desktops — ∞ on every one, 📌 on its
/// screen's — via bridge membership adds, reconciled against
/// the `StickyReach` ledger. Every entry point gates on
/// `canDriveDesktops`; absent bridge, the whole feature is
/// inert and the GUI row is not shown.
extension KiwiCore {
    /// The effective per-window verdict: the
    /// `override_sticky_reach` pin outranks the global
    /// `sticky.desktop_reach` toggle.
    func stickyReachEnabled(for id: WindowID) -> Bool {
        state.stickyReachOverrides[id]
            ?? tiler.settings.stickyStyle.desktopReach
    }

    /// Convenience for a caller holding no topology — a verb, a
    /// settle (the profiles.md snapshot-threading shape).
    func refreshStickyReach() {
        guard canDriveDesktops else { return }
        refreshStickyReach(spaces: NativeSpaces.allSpaces())
    }

    /// Recomputes every sticky window's wanted memberships and
    /// reconciles the ledger — the adds re-issue anything a
    /// past dispatch refused, so re-running after a Desktop
    /// switch is how a fresh Desktop gains its travelers.
    func refreshStickyReach(spaces: [NativeSpace]) {
        guard canDriveDesktops else { return }
        var wanted: [WindowID: Set<SkyLight.SpaceID>] = [:]
        for window in state.windows.all
        where window.stickyScope != .none {
            guard stickyReachEnabled(for: window.id) else {
                continue
            }
            wanted[window.id] = StickyReach.wantedSpaces(
                scope: window.stickyScope,
                homeDisplayUUID: homeDisplayUUID(of: window.id),
                in: spaces
            )
        }
        reconcileStickyReach(wanted: wanted, spaces: spaces)
    }

    /// The one forget rule: only ids the WindowServer itself
    /// forgot. These are the windows the `.appTerminated` fold
    /// removed for THAT pid — never "absent from state", which
    /// also matches a minimized window and anything else still
    /// alive on the reconcile-retire road (a hide, an
    /// ignore-ruled window), whose memberships a forget would
    /// orphan past `retireStickyReach`'s reach.
    func forgetTerminatedStickyReach(_ ids: [WindowID]) {
        for id in ids {
            stickyReach.forget(id)
        }
    }

    /// Teardown (#1145): take every asserted membership back —
    /// quitting must not leave windows parked on Desktops with
    /// nothing left to undo it. The empty want retires through
    /// the one reconcile door, home exclusion included.
    func retireStickyReach() {
        guard canDriveDesktops,
            !stickyReach.asserted.isEmpty
        else { return }
        reconcileStickyReach(
            wanted: [:],
            spaces: NativeSpaces.allSpaces()
        )
    }

    /// `override_sticky_reach` (#1145): pins or clears the
    /// focused window's Desktop-reach verdict.
    func setFocusedStickyReach(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let choice = StickyReachOverride(rawValue: raw)
        else { return Self.reachError }
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        switch choice {
        case .on:
            state.stickyReachOverrides[focused] = true
        case .off:
            state.stickyReachOverrides[focused] = false
        case .auto:
            state.stickyReachOverrides[focused] = nil
        }
        refreshStickyReach()
        return .ok()
    }

    private static let reachError = CommandResponse.expected(
        StickyReachOverride.self
    )

    /// One reconcile pass: the home set is resolved ONCE per
    /// window — wanted and retiring alike — and handed to the
    /// ledger, which excludes it from adds and removals both.
    private func reconcileStickyReach(
        wanted: [WindowID: Set<SkyLight.SpaceID>],
        spaces: [NativeSpace]
    ) {
        var homes: [WindowID: Set<SkyLight.SpaceID>] = [:]
        for id in Set(wanted.keys)
            .union(stickyReach.asserted.keys)
        {
            homes[id] = windowServerHome(of: id, in: spaces)
        }
        stickyReach.reconcile(
            wanted: wanted,
            homes: homes,
            add: { id, adds in
                WMBridge.addWindows([id], to: Array(adds))
            },
            remove: { id, drops in
                WMBridge.removeWindows([id], from: Array(drops))
            }
        )
    }

    /// The display UUID `wantedSpaces` scopes 📌 to — the
    /// window's HOME display, the same primitive the render and
    /// stash exemption rest on (#445).
    private func homeDisplayUUID(of id: WindowID) -> String? {
        state.homeDisplay(of: id).flatMap {
            NativeSpaces.displayUUID(for: $0)
        }
    }

    /// The memberships the WindowServer owns for this window —
    /// its primary space by query, or the home display's
    /// current space where the query answers nothing. #1146
    /// promotes this as the named cross-Desktop seam.
    private func windowServerHome(
        of id: WindowID,
        in spaces: [NativeSpace]
    ) -> Set<SkyLight.SpaceID> {
        if let owned = WMBridge.spaces(for: [id]),
            !owned.isEmpty
        {
            return Set(owned)
        }
        guard let uuid = homeDisplayUUID(of: id) else {
            return []
        }
        return Set(
            spaces
                .filter {
                    $0.displayUUID == uuid && $0.isCurrent
                }
                .map(\.id)
        )
    }
}
