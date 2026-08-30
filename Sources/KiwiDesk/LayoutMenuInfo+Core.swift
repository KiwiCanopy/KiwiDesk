import KiwiDeskCore

/// The one place deriving `LayoutMenuInfo` from live `KiwiCore` state (#752).
extension LayoutMenuInfo {
    @MainActor
    static func current(from core: KiwiCore) -> LayoutMenuInfo {
        let workspaces = core.state.workspaces
        // Drop displays with no active space while display changes settle.
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
