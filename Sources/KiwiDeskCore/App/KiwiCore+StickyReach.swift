import Foundation

/// Sticky Desktop reach (#1145): a sticky window FOLLOWS its
/// screen's Desktop switches, carried by the bridge MOVE — the
/// one membership write macOS applies cross-app, the ADD being a
/// silent no-op (os-private-apis.md). No ledger: where the
/// WindowServer shows the window IS the state. Every entry point
/// gates on `canDriveDesktops`; absent bridge the feature is
/// inert and the GUI row is not shown.
extension KiwiCore {
    /// The effective per-window verdict: the
    /// `override_sticky_reach` pin outranks the global
    /// `sticky.desktop_reach` toggle.
    func stickyReachEnabled(for id: WindowID) -> Bool {
        state.stickyReachOverrides[id]
            ?? tiler.settings.stickyStyle.desktopReach
    }

    /// How long a window stays IN FLIGHT after its stamp — a
    /// dispatched move, or our own switch of its screen (#1213) —
    /// the removal gate's carried arm reads it
    /// (`stickyReachInFlight`). The stamp precedes every measured
    /// death: a native element ~250 ms BEFORE the switch
    /// notification (TextEdit, device 2026-09-02, #1213), an
    /// Electron one ~2 s after it (Claude, device 2026-09-02, the
    /// trace that retired the switch-grace gate); the distrust's
    /// recheck budget (`EventLoop.removalRecheckCap`) comes on
    /// top. Five seconds covers both with margin.
    /// The trade: ⌘W of a sticky window inside those seconds waits
    /// out the recheck budget before its tile goes.
    static let inFlightWindow: TimeInterval = 5

    /// The windows the carry follows — those a pass moves. A
    /// native-fullscreen window keeps its scope but travels
    /// nowhere (#670): a move would yank it out of its own space.
    func stickyReachCarried() -> Set<WindowID> {
        guard canDriveDesktops else { return [] }
        return Set(
            state.windows.all
                .filter {
                    $0.stickyScope != .none && !$0.isFullscreen
                        && stickyReachEnabled(for: $0.id)
                }
                .map(\.id)
        )
    }

    /// The carried windows still in flight — moved within
    /// `inFlightWindow` and still enabled. The event loop's
    /// removal gate reads this through `EventLoop.carriedWindows`:
    /// one of these is EXPECTED present on the arriving Desktop
    /// while the switch transition darkens both AX and the census,
    /// and NOTHING else is — a switch alone opens no arm, so a
    /// sticky window closed with no carry in flight is a close.
    func stickyReachInFlight() -> Set<WindowID> {
        let now = Date()
        stickyReachInFlightAt = stickyReachInFlightAt.filter {
            now.timeIntervalSince($0.value) < Self.inFlightWindow
        }
        return Set(stickyReachInFlightAt.keys)
            .intersection(stickyReachCarried())
    }

    /// Stamps every window the carry WILL move on `displayUUID`
    /// as in flight at our own switch dispatch, before any
    /// notification (#1213, the argument on `inFlightWindow`).
    /// `spaces` is the dispatching verb's own reading (profiles.md).
    func stampStickyReachInFlight(
        forSwitchOn displayUUID: String,
        in spaces: [NativeSpace]
    ) {
        guard canDriveDesktops else { return }
        let carried = stickyReachCarried()
        let now = Date()
        let stamped = state.windows.all
            .filter { carried.contains($0.id) }
            .filter { renderDisplayUUID(of: $0, in: spaces) == displayUUID }
            .map(\.id)
            .sorted { $0.raw < $1.raw }
        guard !stamped.isEmpty else { return }
        for id in stamped { stickyReachInFlightAt[id] = now }
        onLog(
            "reach: in flight for the dispatched switch: "
                + stamped.map { "w\($0.raw)" }.joined(separator: " ")
        )
    }

    /// Convenience for a caller holding no topology — a verb, a
    /// settle (the profiles.md snapshot-threading shape).
    func refreshStickyReach() {
        guard canDriveDesktops else { return }
        refreshStickyReach(spaces: NativeSpaces.allSpaces())
    }

    /// Carries every enabled sticky window onto the CURRENT
    /// Desktop of the screen it renders on — one idempotent pass
    /// the switch handler runs eagerly and the settle repeats, so
    /// a switch the eager pass missed self-heals. The screen is
    /// #445's render primitive (`stickyRenderSpace`): 📌 its home
    /// screen, ∞ the active space's — so the carry lands where
    /// the retile draws the window, and a window never crosses
    /// screens because some OTHER screen switched. A screen
    /// showing a fullscreen or system space carries nothing —
    /// its next user Desktop does (#670).
    func refreshStickyReach(spaces: [NativeSpace]) {
        guard canDriveDesktops else { return }
        let carried = stickyReachCarried()
        for window in state.windows.all
            .filter({ carried.contains($0.id) })
            .sorted(by: { $0.id.raw < $1.id.raw })
        {
            let id = window.id
            guard
                let uuid = renderDisplayUUID(of: window, in: spaces),
                let current = spaces.first(where: {
                    $0.displayUUID == uuid && $0.isCurrent
                        && $0.isUser
                })
            else { continue }
            // Performed is not applied (os-private-apis.md): the
            // Bool is the dispatch, nothing verifies the landing,
            // and the settle's repeat is the only net.
            let performed = WMBridge.moveWindows([id], to: current.id)
            // In flight only for a move that was DISPATCHED: a
            // refused one moved nothing, so nothing is expected
            // to vanish and ⌘W must not wait on it.
            if performed { stickyReachInFlightAt[id] = Date() }
            onLog(
                "reach: carry w\(id.raw) -> space \(current.id) "
                    + "performed=\(performed)"
            )
        }
    }

    /// `override_sticky_reach` (#1145): pins or clears the
    /// focused window's Desktop-reach verdict and carries now.
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

    /// The screen a carry is scoped to — the display of the
    /// space the window RENDERS on (#445's `stickyRenderSpace`,
    /// read as `focusAnchor` reads it). One display record means
    /// shared-Spaces mode: everything carries with the one list.
    private func renderDisplayUUID(
        of window: ManagedWindow,
        in spaces: [NativeSpace]
    ) -> String? {
        let uuids = Set(spaces.map(\.displayUUID))
        if uuids.count <= 1 { return uuids.first }
        return state.stickyRenderSpace(of: window)
            .flatMap { state.workspaces.display(of: $0) }
            .flatMap { NativeSpaces.displayUUID(for: $0) }
    }
}
