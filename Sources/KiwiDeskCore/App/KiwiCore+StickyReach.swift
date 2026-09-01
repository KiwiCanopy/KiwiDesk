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

    /// The windows the carry follows. Also the event loop's
    /// removal gate's reading (`EventLoop.carriedWindows`): one
    /// of these is EXPECTED present on the arriving Desktop while
    /// the switch transition darkens both AX and the census. A
    /// native-fullscreen window keeps its scope but travels
    /// nowhere (#670) — a move would yank it out of its own space.
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
        return state.stickyRenderSpace(of: window, focused: nil)
            .flatMap { state.workspaces.display(of: $0) }
            .flatMap { NativeSpaces.displayUUID(for: $0) }
    }
}
