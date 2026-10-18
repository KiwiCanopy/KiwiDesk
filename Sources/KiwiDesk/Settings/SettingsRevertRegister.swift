import KiwiDeskCore

/// Every census key's way back to the draft's baseline (#792): the
/// one register a diff row's revert reads, total over the keys that
/// name a model path (`SettingsRevertRegisterTests`). The settings
/// half is generated from the census ids; this file holds the
/// config half, whose fields couple to the rule reach (#1393).
@MainActor
enum SettingsRevertRegister {
    static let writers: [SettingKey: RevertWriter] =
        settings1.merging(settings2) { a, _ in a }
        .merging(settings3) { a, _ in a }
        .merging(masters) { _, b in b }
        .merging(config) { _, b in b }

    /// A master writes its followers (`SettingKey.masterWrites`).
    static let masters: [SettingKey: RevertWriter] = [
        .kiwishelf(.edge): .all([
            .leaf(\.settings.spaceBarStyle.edge),
            .leaf(\.settings.appBarStyle.edge),
        ]),
        .colours(.liquidGlassMaster): .all([
            .leaf(\.settings.kiwishelf.liquidGlass),
            .leaf(\.settings.shortcutPanelLiquidGlass),
            .leaf(\.settings.dragLiquidGlass),
            .leaf(\.settings.stickyStyle.liquidGlass),
        ]),
    ]

    static let config: [SettingKey: RevertWriter] = [
        .appRules(.appRules): RevertWriter.entry(
            \.appRules,
            key: { $0 }
        ).then { model, app in
            settleSubject(model, .space, app ?? "", \.appRules) {
                $0.lowercased()
            }
        },
        .appRules(.floatRules): floatRules,
        .appRules(.floatRulesPattern): floatRules,
        .appRules(.ignoreRules): .list(\.ignoreRules),
        .appRules(.tileRules): RevertWriter.list(\.tileRules).then {
            settleListSubject($0, .tile, $1, \.tileRules)
        },
        .appRules(.floatAutomatically): RevertWriter.leaf(
            \.floatAutomatically
        ).then(settles(.autoFloat, \.floatAutomatically)),
        .screens(.spacePins): .entry(\.spacePins, key: { SpaceID($0) }),
        .screens(.mainSpaces): .leaf(\.mainSpaces),
        .profiles(.profileBindings): .entry(
            \.profileBindings,
            key: DesktopKey.init(stored:)
        ),
        .shortcuts(.layers): layers,
        .shortcuts(.layersIcon): layers,
        .shortcuts(.desktopShortcutBase): layers,
        .shortcuts(.spaceHistory): RevertWriter.leaf(
            \.spaceHistory
        ).then(settles(.history, \.spaceHistory)),
        .shortcuts(.modeCycle): RevertWriter.leaf(\.modeCycle)
            .then(settles(.cycle, \.modeCycle)),
        .shortcuts(.scrollPan): scroll(\.scrollGesture.pan),
        .shortcuts(.scrollLongSwipes): scroll(\.scrollGesture.longSwipes),
        .shortcuts(.scrollStepDistance): scroll(
            \.scrollGesture.stepDistance
        ),
        .shortcuts(.scrollNaturalTrackpad): scroll(
            \.scrollGesture.naturalTrackpad
        ),
        .shortcuts(.scrollNaturalMouse): scroll(
            \.scrollGesture.naturalMouse
        ),
        .shortcuts(.scrollSpaceStep): scroll(\.scrollGesture.spaceStep),
        .spaces(.spaceList): .members(\.spaces, key: { SpaceID($0) }),
        .spaces(.spacesName): .members(\.spaces, key: { SpaceID($0) }),
        .spaces(.spaceModes): .entry(\.spaceModes, key: { SpaceID($0) }),
        .spaces(.fallbackSpace): .leaf(\.fallbackSpace),
    ]

    /// The float rules, the subject's reach settling with them.
    private static let floatRules = RevertWriter.list(\.floatRules)
        .then { settleListSubject($0, .float, $1, \.floatRules) }

    /// The shortcut layers whole, with the Desktop base drafted
    /// beside them (#1870) and every key reach and layer edit, as
    /// `dropRuleHalf` drops them: a binding's reach is keyed into
    /// the layers it was encoded against (#2022).
    private static let layers = RevertWriter.all([
        .leaf(\.layers), .leaf(\.desktopShortcutBase),
    ]).then { model, _ in
        model.reachEdits.reach[.key] = nil
        model.reachEdits.removal[.key] = nil
        model.reachEdits.layers = [:]
        model.reachEdits.deletedLayers = [:]
    }

    private static func scroll<V: Equatable>(
        _ path: WritableKeyPath<GuiConfig, V>
    ) -> RevertWriter {
        RevertWriter.leaf(path).then(settles(.scroll, \.scrollGesture))
    }

    /// A family's reach goes once its field is the baseline's.
    private static func settles<V: Equatable>(
        _ family: RuleFamily,
        _ path: KeyPath<GuiConfig, V>
    ) -> (SettingsModel, String?) -> Void {
        { model, _ in
            let clean = model.cleanConfig[keyPath: path]
            guard model.config[keyPath: path] == clean else { return }
            model.reachEdits.reach[family] = nil
            model.reachEdits.removal[family] = nil
        }
    }

    /// One app's reach goes once its rule is the baseline's.
    private static func settleSubject<V: Equatable>(
        _ model: SettingsModel,
        _ family: RuleFamily,
        _ app: String,
        _ path: KeyPath<GuiConfig, [String: V]>,
        key: @escaping (String) -> String
    ) {
        let subject = key(app)
        let match = { (map: [String: V]) in
            map.filter { key($0.key) == subject }
        }
        guard
            match(model.config[keyPath: path])
                == match(model.cleanConfig[keyPath: path])
        else { return }
        model.reachEdits.reach[family]?[subject] = nil
        model.reachEdits.removal[family]?[subject] = nil
    }

    /// A list rule's app reach goes once its rules are the
    /// baseline's.
    private static func settleListSubject(
        _ model: SettingsModel,
        _ family: RuleFamily,
        _ instance: String?,
        _ path: KeyPath<GuiConfig, [String]>
    ) {
        guard let instance, let entry = RevertWriter.listEntry(instance)
        else {
            settles(family, path)(model, nil)
            return
        }
        let subject = family.key(entry.entry)
        let match = { (list: [String]) in
            list.filter { family.key($0) == subject }
        }
        guard
            match(model.config[keyPath: path])
                == match(model.cleanConfig[keyPath: path])
        else { return }
        model.reachEdits.reach[family]?[subject] = nil
        model.reachEdits.removal[family]?[subject] = nil
    }
}
