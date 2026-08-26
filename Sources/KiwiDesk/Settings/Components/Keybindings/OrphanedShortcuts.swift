import KiwiDeskCore

/// Which catalog commands are orphaned in `bindings` relative to
/// `spaces` — the pure half of `OrphanedShortcutsGroup`, split
/// out for tests and now consumed by TWO surfaces: that Settings
/// section (#92) and the ⌃⌥K panel's Inactive band (#820). It
/// lives beside the section for history rather than ownership;
/// it is nobody's widget, and a third surface asking "is this
/// binding inactive?" asks HERE rather than re-deriving it —
/// two surfaces disagreeing about what is inactive is the whole
/// defect #820 was.
enum OrphanedShortcuts {
    /// One catalog command per orphaned binding, in binding
    /// order (deduplicated by Lua — `NavRow` keys rows by it).
    /// Only `.navigation` rows count: a `.custom` row with
    /// space-targeting Lua already shows in the Advanced
    /// drawer. The command is rebuilt through the catalog for
    /// the orphan's space, so its Lua matches the binding
    /// byte-for-byte and the row behaves like any preset row.
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

    /// Every command a per-space FAMILY draws for one space —
    /// derived from the census families rather than hand-listed.
    ///
    /// This card is the safety net for #92: a space-targeting
    /// binding whose space has left the list is still
    /// Carbon-registered, still blocks the recorder, and would
    /// otherwise be invisible. That net is only as wide as the
    /// set of families it knows about, so hand-listing them here
    /// meant a fifth per-space family would compile, red the
    /// render guard, and be silently omitted from the one card
    /// that exists to catch it. Asking the expander instead makes
    /// the two grow together; `perSpaceFamilies` is the one place
    /// that says which families are per-space, and
    /// `OrphanedShortcutsTests` pins that the net covers all of
    /// them.
    @MainActor
    static func perSpaceCommands(
        for space: SpaceID,
        icons: [SpaceID: String]
    ) -> [NavCommand] {
        let expander = ShortcutsFamilyRows(
            spaces: [space],
            icons: icons,
            // None of these reaches a per-space family; all are
            // required by the type and irrelevant here. The
            // empty Desktop list is deliberate rather than
            // incidental: this card is the SPACE net, and a
            // Desktop number is not a `SpaceID` — see
            // `KeybindingCatalog.desktopOffer`, which is how
            // a Desktop row stays reachable instead.
            desktops: .none,
            resizeStep: 0,
            layerNames: [],
            currentLayer: ""
        )
        return perSpaceFamilies.flatMap {
            expander.rows(for: $0) ?? []
        }
    }

    /// The census families that expand once per space. Data, so
    /// the card above and the guard read one list.
    static let perSpaceFamilies: [SettingKey] = [
        .shortcuts(.goToSpace),
        .shortcuts(.moveToSpace),
        .shortcuts(.moveToSpaceFollow),
    ]
}
