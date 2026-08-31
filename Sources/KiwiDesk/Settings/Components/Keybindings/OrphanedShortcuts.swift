import KiwiDeskCore

/// Determines orphaned catalog commands for deleted spaces (#92, #820).
enum OrphanedShortcuts {
    /// Reconstructs navigation commands for bindings targeting inactive spaces
    /// (`NavRow`, `SpaceLuaArg`, #92, #820).
    @MainActor
    static func commands(
        bindings: [KeyBinding],
        spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        let live = Set(spaces)
        var seen: Set<String> = []
        var commands: [NavCommand] = []
        for binding in bindings
        where binding.kind == .navigation {
            guard
                let space = SpaceLuaArg.targetSpace(
                    of: binding.lua
                ),
                !live.contains(space),
                !seen.contains(binding.lua)
            else { continue }
            let candidates = perSpaceCommands(
                for: space,
                icons: icons
            )
            guard
                let command = candidates.first(where: {
                    $0.lua == binding.lua
                })
            else { continue }
            seen.insert(binding.lua)
            commands.append(command)
        }
        return commands
    }

    /// Generates per-space family commands (`ShortcutsFamilyRows`,
    /// `KeybindingCatalog.desktopOffer`, `OrphanedShortcutsTests`, #92).
    @MainActor
    static func perSpaceCommands(
        for space: SpaceID,
        icons: [SpaceID: String]
    ) -> [NavCommand] {
        let expander = ShortcutsFamilyRows(
            spaces: [space],
            icons: icons,
            desktops: .none,
            resizeStep: 0,
            layerNames: [],
            currentLayer: ""
        )
        return perSpaceFamilies.flatMap {
            expander.rows(for: $0) ?? []
        }
    }

    /// Census families expanding once per space.
    static let perSpaceFamilies: [SettingKey] = [
        .shortcuts(.goToSpace),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
    ]
}
