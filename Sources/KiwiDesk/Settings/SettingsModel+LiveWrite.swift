import KiwiDeskCore

/// A write of the live profile from outside Settings, which Core
/// announces through `onLiveProfileWritten` — the tour's look
/// (#1720), a bar menu's row (#1518), a Space added to or removed
/// from the profile by the bar's Delete, `create_space` /
/// `delete_space` with `profile`, or Settings ▸ Spaces' own add
/// button (#1790), and an AI app's `keep_settings` (#1685).
/// profiles.md rules the draft policy.
extension SettingsModel {
    /// A clean draft re-reads. A dirty one takes a `persisted`
    /// edit on both sides of its diff, so the change is neither
    /// lost at the next Save nor counted as the user's — and on a
    /// leaf the draft had itself staged, the write, the newer act,
    /// wins — and an edit no file took as any live change, its
    /// settings rebased under the draft's own edits and listed
    /// "Live, not saved" (#2262). A stored profile's draft is
    /// another file, which the write did not reach.
    func adoptLiveWrite(_ edit: LiveProfileEdit, persisted: Bool) {
        guard target == .live else { return }
        guard isDirty else {
            reload()
            return
        }
        guard persisted else {
            // A session-only write is a live change like a verb's:
            // taken as one, listed "Live, not saved" (#2262).
            adoptLiveSettings()
            return
        }
        suppressDirty = true
        config.apply(edit)
        cleanConfig.apply(edit)
        suppressDirty = false
        recomputeDirty()
        // A keep or a menu row may have saved a live row (#2262).
        refreshUnsavedLive()
    }

    /// A gone Space's shortcuts left the base and every profile
    /// (#1827), so a draft of ANY target takes it: a clean one
    /// re-reads, a dirty one drops the rows on both sides of its
    /// diff and re-reads the stored tables its Save diffs against,
    /// or that Save would write the rows back.
    func adoptShortcutDrop(_ spaces: Set<SpaceID>) {
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        config.layers = config.layers.removingRows(naming: spaces).layers
        cleanConfig.layers =
            cleanConfig.layers.removingRows(naming: spaces).layers
        if profileEditingBaseLayers != nil {
            profileEditingBaseLayers = core.baseKeyLayers()
        }
        ruleReachStored = core.ruleReachSnapshot()
        suppressDirty = false
        recomputeDirty()
    }

    /// A top-up appended rows to the base layer, which every
    /// profile inherits, so a draft of ANY target takes them: a
    /// clean one re-reads, a dirty one adds the rows on both sides
    /// of its diff, or its Save would drop them.
    func adoptShortcutAdd(_ rows: [KeyBinding]) {
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        // A staged Hyper move (#1870) carries its Desktop base: the
        // draft's copy of a new Desktop row takes it, so Save writes
        // one ladder.
        let staged = config.desktopShortcutBase
        Self.appendToDefault(
            rows.map { DefaultKeybindings.rebased($0, onto: staged) },
            in: &config.layers
        )
        Self.appendToDefault(rows, in: &cleanConfig.layers)
        if profileEditingBaseLayers != nil {
            profileEditingBaseLayers = core.baseKeyLayers()
        }
        ruleReachStored = core.ruleReachSnapshot()
        suppressDirty = false
        recomputeDirty()
    }

    /// An AI app's keep wrote rules (#1685 ▸ Ruling 6c) — the
    /// shared base or a profile's own — so a draft of ANY target
    /// re-reads the stored tables its Save diffs against: a clean
    /// draft re-reads whole, and a dirty one takes each rule the
    /// keep changed on its page on both sides of its diff, the newer
    /// act winning, as `adoptLiveWrite` does — or its Save would
    /// encode the old rule back over the keep.
    func adoptRuleKeep() {
        guard isDirty else {
            reload()
            return
        }
        suppressDirty = true
        let before = ruleReachStored
        ruleReachStored = core.ruleReachSnapshot()
        if let page = reachPage, let stored = ruleReachStored {
            let old = cleanConfig
            Self.takeKeptRules(stored, page: page, over: old, into: &config)
            Self.takeKeptRules(
                stored,
                page: page,
                over: old,
                into: &cleanConfig
            )
            if let before {
                let moved = Self.movedShortcuts(before, stored, page: page)
                Self.takeShortcuts(moved, into: &config.layers)
                Self.takeShortcuts(moved, into: &cleanConfig.layers)
            }
        }
        suppressDirty = false
        recomputeDirty()
    }

    /// Lays `page`'s rules as the files hold them now over `config`
    /// wherever they differ from `old`, the draft's last read.
    static func takeKeptRules(
        _ stored: RuleReachSnapshot,
        page: String,
        over old: GuiConfig,
        into config: inout GuiConfig
    ) {
        let apps = stored.appRules.resolved(for: page)
        for app in Set(old.appRules.keys).union(apps.keys)
        where old.appRules[app] != apps[app] {
            config.appRules[app] = apps[app]
        }
        let was = Set(old.floatRules.map(FloatRules.normalizedRule))
        let now = Set(stored.floatRules.resolved(for: page).values.joined())
        let gone = was.subtracting(now)
        var floats = config.floatRules.filter {
            !gone.contains(FloatRules.normalizedRule($0))
        }
        floats += now.subtracting(was)
            .subtracting(floats.map(FloatRules.normalizedRule)).sorted()
        config.floatRules = floats
        let auto =
            stored.floatAutomatically.resolved(
                RuleReachTable<Bool>.floatAutomaticallyKey,
                for: page
            ) ?? stored.floatAutomatically.floatAutomaticallyBase
        if auto != old.floatAutomatically {
            config.floatAutomatically = auto
        }
    }

    /// The shortcuts whose combo on `page` an outside write changed,
    /// by `layer␟lua` key: the new combo, nil for an unbound one.
    static func movedShortcuts(
        _ before: RuleReachSnapshot,
        _ after: RuleReachSnapshot,
        page: String
    ) -> [String: String?] {
        let old = before.keyLayers.resolved(for: page)
        let new = after.keyLayers.resolved(for: page)
        var moved: [String: String?] = [:]
        for key in Set(old.keys).union(new.keys) where old[key] != new[key] {
            moved[key] = .some(new[key])
        }
        return moved
    }

    /// Lays `moved` over `layers`: a row's combo set, a row added, or
    /// an unbound row dropped — a row matched by the action it runs
    /// (`NavigationChords.sameAction`), and a written chord taken
    /// from any other row holding it, the newer act winning.
    static func takeShortcuts(
        _ moved: [String: String?],
        into layers: inout [KeyLayer]
    ) {
        for (key, combo) in moved.sorted(by: { $0.key < $1.key }) {
            let parts = RuleReachTable<String>.keyParts(key)
            guard let at = layers.firstIndex(where: { $0.name == parts.layer })
            else { continue }
            let written = KeyBinding(combo: combo ?? "", lua: parts.lua)
            var placed = false
            var rows: [KeyBinding] = []
            for var row in layers[at].bindings {
                if NavigationChords.sameAction(row, written) {
                    // The action keeps its place, once, at the chord.
                    guard let combo, !placed else { continue }
                    row.combo = combo
                    placed = true
                } else if let combo, row.combo == combo {
                    continue
                }
                rows.append(row)
            }
            if combo != nil, !placed { rows.append(written) }
            layers[at].bindings = rows
        }
    }

    /// Appends `rows` to the default layer, skipping a row whose
    /// action that layer already runs.
    private static func appendToDefault(
        _ rows: [KeyBinding],
        in layers: inout [KeyLayer]
    ) {
        guard let index = layers.firstIndex(where: { $0.isDefault }) else {
            return
        }
        let bound = Set(layers[index].bindings.map(\.lua))
        layers[index].bindings.append(
            contentsOf: rows.filter { !bound.contains($0.lua) }
        )
    }
}
