import KiwiDeskCore

/// The rule families' writers (#792): a reverted rule takes the
/// reach the draft gave it along (#1393), read through the one
/// `RuleFamilyField` table and keyed as the family keys a subject.
extension SettingsRevertRegister {
    static let rules: [SettingKey: RevertWriter] = [
        .appRules(.appRules): RevertWriter.entry(
            \.appRules,
            key: { $0 }
        ).then { model, app in
            settle(model, .space, app.map(RuleFamily.space.key))
        },
        .appRules(.floatRules): ruleList(\.floatRules, .float),
        .appRules(.floatRulesPattern): ruleList(\.floatRules, .float),
        .appRules(.tileRules): ruleList(\.tileRules, .tile),
        .appRules(.floatAutomatically): RevertWriter.leaf(
            \.floatAutomatically
        ).then { model, _ in settle(model, .autoFloat, nil) },
        .shortcuts(.layers): layers,
        .shortcuts(.layersIcon): layerIcon,
        .shortcuts(.shortcutBase): shortcutBase,
        .shortcuts(.spaceHistory): RevertWriter.leaf(
            \.spaceHistory
        ).then { model, _ in settle(model, .history, nil) },
        .shortcuts(.focusWrap): RevertWriter.leaf(
            \.focusWrap
        ).then { model, _ in settle(model, .wrap, nil) },
        .shortcuts(.modeCycle): RevertWriter.leaf(\.modeCycle)
            .then { model, _ in settle(model, .cycle, nil) },
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
        .shortcuts(.pocketEdge): .leaf(\.settings.kiwishelf.pocketEdge),
        .shortcuts(.pocketPosition): .leaf(
            \.settings.kiwishelf.pocketPosition
        ),
    ]

    /// One app's rules back to the baseline, with the reach the
    /// draft gave them — a reach row's ↺, which reports the rule's
    /// effect on another profile (#1393).
    static func revertSubject(
        _ model: SettingsModel,
        _ family: RuleFamily,
        _ subject: String
    ) {
        let clean = model.cleanConfig
        var config = model.config
        switch family {
        case .space:
            let mine = { family.key($0) == subject }
            config.appRules = config.appRules.filter { !mine($0.key) }
                .merging(clean.appRules.filter { mine($0.key) }) { $1 }
        case .float:
            config.floatRules = merged(
                config.floatRules,
                clean.floatRules,
                family,
                subject
            )
        case .tile:
            config.tileRules = merged(
                config.tileRules,
                clean.tileRules,
                family,
                subject
            )
        default:
            break
        }
        model.config = config
        settle(model, family, subject)
    }

    /// A rule list's rows, the entry's app reach settling with it.
    private static func ruleList(
        _ path: WritableKeyPath<GuiConfig, [String]>,
        _ family: RuleFamily
    ) -> RevertWriter {
        RevertWriter.list(path).then { model, instance in
            let entry = instance.flatMap(ListEntryInstance.init(parsing:))
            settle(
                model,
                family,
                entry.map { family.subject(ofRule: $0.entry) }
            )
        }
    }

    /// The shortcut layers whole, with the Desktop base drafted
    /// beside them (#1870) and every key reach and layer edit, as
    /// `dropRuleHalf` drops them: the way back of a "Layers edited"
    /// row, which names no binding or layer. A binding's or a
    /// layer's own row reverts through its own case (#2412).
    private static let layers = RevertWriter.all([
        .leaf(\.layers), .leaf(\.shortcutBase),
    ]).then { model, _ in
        model.reachEdits.reach[.key] = nil
        model.reachEdits.removal[.key] = nil
        model.reachEdits.layers = [:]
        model.reachEdits.deletedLayers = [:]
    }.grouped()

    /// One layer's icon, named by its row; every layer's for a row
    /// naming none.
    private static let layerIcon = RevertWriter(
        paths: ["config.layers[].icon"]
    ) { model, instance in
        let clean = model.cleanConfig.layers
        for at in model.config.layers.indices {
            let name = model.config.layers[at].name
            guard instance == nil || instance == name,
                let saved = clean.first(where: { $0.name == name })
            else { continue }
            model.config.layers[at].icon = saved.icon
        }
    }

    /// The shortcut base back: every row moves back as the switch
    /// moves it, a row added on the staged base included, and a row
    /// that is then a saved row in all but spelling takes the saved
    /// spelling, so the switch's own rows leave the list (#2460).
    private static let shortcutBase = RevertWriter(
        paths: ["config.shortcutBase"]
    ) { model, _ in
        let clean = model.cleanConfig
        model.setShortcutBase(clean.shortcutBase)
        for at in model.config.layers.indices {
            let saved = model.savedLayerName(model.config.layers[at].name)
            let was = clean.layers.first { $0.name == saved }?.bindings ?? []
            model.config.layers[at].bindings =
                model.config.layers[at].bindings.map { row in
                    was.first { sameRow($0, row) } ?? row
                }
        }
    }

    /// Whether two rows run one action on one chord, however each
    /// spells it.
    private static func sameRow(_ a: KeyBinding, _ b: KeyBinding) -> Bool {
        guard a.lua == b.lua else { return false }
        return a.combo == b.combo
            || (KeyCombo.parse(a.combo).map { $0 == KeyCombo.parse(b.combo) }
                ?? false)
    }

    private static func scroll<V>(
        _ path: WritableKeyPath<GuiConfig, V>
    ) -> RevertWriter {
        RevertWriter.leaf(path).then { model, _ in
            settle(model, .scroll, nil)
        }
    }

    /// A family's reach goes where its rules are the baseline's
    /// again: one subject's, or the whole family's.
    private static func settle(
        _ model: SettingsModel,
        _ family: RuleFamily,
        _ subject: String?
    ) {
        guard let subject else {
            guard
                RuleFamilyField.of(family)?.same(
                    model.config,
                    model.cleanConfig
                ) == true
            else { return }
            model.reachEdits.reach[family] = nil
            model.reachEdits.removal[family] = nil
            return
        }
        guard
            rules(of: subject, family, in: model.config)
                == rules(of: subject, family, in: model.cleanConfig)
        else { return }
        model.reachEdits.reach[family]?[subject] = nil
        model.reachEdits.removal[family]?[subject] = nil
    }

    /// One subject's rules in `config`, comparable across configs.
    private static func rules(
        of subject: String,
        _ family: RuleFamily,
        in config: GuiConfig
    ) -> [String] {
        switch family {
        case .space:
            return config.appRules.filter { family.key($0.key) == subject }
                .map { $0.key + "=" + $0.value.raw }.sorted()
        case .float:
            return config.floatRules.filter {
                family.subject(ofRule: $0) == subject
            }
        case .tile:
            return config.tileRules.filter {
                family.subject(ofRule: $0) == subject
            }
        default:
            return []
        }
    }

    /// `draft` with the subject's rules swapped for `clean`'s, at
    /// the place the first of them held.
    private static func merged(
        _ draft: [String],
        _ clean: [String],
        _ family: RuleFamily,
        _ subject: String
    ) -> [String] {
        let mine = { family.subject(ofRule: $0) == subject }
        let at = draft.firstIndex(where: mine)
        var rules = draft.filter { !mine($0) }
        let place = min(at ?? rules.count, rules.count)
        rules.insert(contentsOf: clean.filter(mine), at: place)
        return rules
    }
}
