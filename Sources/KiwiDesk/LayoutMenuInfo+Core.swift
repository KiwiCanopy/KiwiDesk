import KiwiDeskCore

/// Reading the Layout submenu's state off the live core (#752).
///
/// Split from the value type so `LayoutMenuInfo` itself stays
/// free of `KiwiCore` — the struct is what the controller and the
/// test fake speak, and this is the one place that knows where
/// its fields come from. It is also what makes the derivation
/// testable without a menu: a suite can seed two displays and
/// assert the info, which is where the ordering and the
/// per-screen drift verdicts actually get checked.
extension LayoutMenuInfo {
    @MainActor
    static func current(from core: KiwiCore) -> LayoutMenuInfo {
        let workspaces = core.state.workspaces
        // A display with no space showing on it is dropped rather
        // than drawn empty: there is no layout to check, nothing
        // to set it to, and a row that cannot answer is worse
        // than no row. Reachable while a display change settles.
        let shown = workspaces.allDisplays.compactMap {
            display -> (display: Display, space: SpaceID)? in
            guard
                let space = workspaces.activeSpace(on: display.id)
            else { return nil }
            return (display, space)
        }
        let saved = core.savedModes(for: shown.map(\.space))
        return LayoutMenuInfo(
            activeMode: core.activeSpace?.mode,
            activeProfileName: core.profiles.currentName,
            savedModeForActiveSpace: core.savedModeForActiveSpace(),
            screens: shown.map { entry in
                Screen(
                    space: entry.space,
                    name: entry.display.name,
                    id: entry.display.id,
                    origin: entry.display.frame.origin,
                    mode: workspaces[entry.space]?.mode,
                    savedMode: saved[entry.space]
                )
            }
        )
    }
}
