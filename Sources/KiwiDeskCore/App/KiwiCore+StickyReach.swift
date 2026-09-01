import Foundation

/// Sticky Desktop reach (#1145): a sticky window is genuinely
/// present across macOS Desktops — ∞ on every one, 📌 on its
/// screen's — via bridge membership adds, reconciled against
/// the `StickyReach` ledger. Every entry point gates on
/// `canDriveDesktops`; absent bridge, the whole feature is
/// inert and the GUI row is not shown.
extension KiwiCore {
    /// The effective per-window verdict: the `override_sticky_reach`
    /// override outranks the global `sticky.desktop_reach`
    /// toggle.
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
    /// dispatches the ledger diff. Idempotent by design —
    /// re-running after a Desktop switch is how a Desktop born
    /// since the last refresh gains its travelers, and nothing
    /// can query membership instead (#889 item 5).
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
                excluding: windowServerHome(
                    of: window.id,
                    in: spaces
                ),
                in: spaces
            )
        }
        dispatchStickyReach(
            stickyReach.reconcile(wanted: wanted),
            spaces: spaces
        )
    }

    /// Teardown (#1145): take every asserted membership back —
    /// quitting must not leave windows parked on Desktops with
    /// nothing left to undo it. Routed through the one dispatch
    /// door so the home-space exclusion applies here too.
    func retireStickyReach() {
        guard canDriveDesktops else { return }
        let held = stickyReach.drainAll()
        guard !held.isEmpty else { return }
        dispatchStickyReach(
            StickyReach.Step(add: [:], remove: held),
            spaces: NativeSpaces.allSpaces()
        )
    }

    /// `override_sticky_reach` (#1145): pins or clears the focused
    /// window's Desktop-reach override.
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
    /// current space where the query answers nothing. Excluded
    /// from every add AND every removal: a removal naming the
    /// space a window lives on takes it off its own Desktop,
    /// and the primary can migrate INTO an asserted space when
    /// the user moves the window (so the add-side exclusion
    /// alone is not enough).
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

    private func dispatchStickyReach(
        _ step: StickyReach.Step,
        spaces: [NativeSpace]
    ) {
        for (id, adds) in step.add where !adds.isEmpty {
            _ = WMBridge.addWindows([id], to: Array(adds))
        }
        for (id, drops) in step.remove {
            let keep = windowServerHome(of: id, in: spaces)
            let safe = drops.subtracting(keep)
            guard !safe.isEmpty else { continue }
            _ = WMBridge.removeWindows([id], from: Array(safe))
        }
    }
}
