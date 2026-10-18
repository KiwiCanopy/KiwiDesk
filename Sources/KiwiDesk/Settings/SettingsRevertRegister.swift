import KiwiDeskCore

/// Every census key's way back to the draft's baseline (#792): the
/// one register a diff row's revert reads, total over the keys that
/// name a model path (`SettingsRevertRegisterTests`). A writer is
/// written against its key's census id, which is its Swift path;
/// this file holds the masters and the config fields, `+Rules` the
/// rule families, whose reach goes with them (#1393).
@MainActor
enum SettingsRevertRegister {
    static let writers: [SettingKey: RevertWriter] =
        parts.reduce(into: [:]) { $0.merge($1) { a, _ in a } }

    /// The register's parts, whose keys never overlap
    /// (`SettingsRevertRegisterTests`).
    static let parts: [[SettingKey: RevertWriter]] = [
        settings1, settings2, settings3, masters, config, rules,
    ]

    /// A master writes its followers (`SettingKey.masterWrites`).
    /// A bar's edge and its per-screen map go back as one pair,
    /// since the edge doors write them together (`ScreenEdged`):
    /// a pair the baseline held is never a pin the doors forbid.
    static let masters: [SettingKey: RevertWriter] = [
        .kiwishelf(.edge): .all([spaceBarEdge, appBarEdge]),
        .kiwishelf(.spaceBarEdge): spaceBarEdge,
        .kiwishelf(.spaceBarScreenEdge): spaceBarEdge,
        .kiwishelf(.appBarEdge): appBarEdge,
        .kiwishelf(.appBarScreenEdge): appBarEdge,
        .colours(.liquidGlassMaster): .all([
            .leaf(\.settings.kiwishelf.liquidGlass),
            .leaf(\.settings.shortcutPanelLiquidGlass),
            .leaf(\.settings.dragLiquidGlass),
            .leaf(\.settings.stickyStyle.liquidGlass),
        ]),
    ]

    private static let spaceBarEdge = RevertWriter.all([
        .leaf(\.settings.spaceBarStyle.edge),
        .leaf(\.settings.spaceBarStyle.edgeOverride),
    ])
    private static let appBarEdge = RevertWriter.all([
        .leaf(\.settings.appBarStyle.edge),
        .leaf(\.settings.appBarStyle.edgeOverride),
    ])

    static let config: [SettingKey: RevertWriter] = [
        .appRules(.ignoreRules): .list(\.ignoreRules),
        .screens(.spacePins): .entry(\.spacePins, key: { SpaceID($0) }),
        .screens(.mainSpaces): .setMember(\.mainSpaces) { SpaceID($0) },
        .profiles(.profileBindings): .entry(
            \.profileBindings,
            key: DesktopKey.init(stored:)
        ),
        .spaces(.spaceList): spaceList,
        .spaces(.spacesName): spaceName,
        .spaces(.spaceModes): .entry(\.spaceModes, key: { SpaceID($0) }),
        .spaces(.fallbackSpace): .leaf(\.fallbackSpace),
    ]

    /// The Space list through its doors (#68), since a Space owns
    /// what is filed under it: an added Space leaves with all of
    /// it, a removed one returns as the baseline held it, and a
    /// row naming none — a reorder — takes the baseline's order.
    private static let spaceList = RevertWriter(
        paths: ["config.spaces"]
    ) { model, instance in
        let clean = model.cleanConfig
        var config = model.config
        if let instance {
            let space = SpaceID(instance)
            if clean.spaces.contains(space) {
                config.restoreSpace(space, from: clean)
            } else {
                config.removeSpace(space)
            }
        } else if Set(config.spaces) == Set(clean.spaces) {
            config.spaces = clean.spaces
        }
        model.config = config
    }

    /// A renamed Space takes its old name back through the rename
    /// door, which moves what is filed under it. The old name is
    /// the baseline's at the same place, as the rename row reads it.
    private static let spaceName = RevertWriter(
        paths: ["config.spaces"]
    ) { model, instance in
        let clean = model.cleanConfig.spaces
        var config = model.config
        guard let instance, clean.count == config.spaces.count,
            let at = config.spaces.firstIndex(of: SpaceID(instance))
        else { return }
        _ = config.renameSpace(from: SpaceID(instance), to: clean[at])
        model.config = config
    }
}
