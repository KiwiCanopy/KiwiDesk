import KiwiDeskCore

/// The Simple / Advanced roots (#2737) and the facts Simple's
/// header draws.
extension SettingsModel {
    /// Whether the window draws Simple's page: its root, outside
    /// the Lua editor. No page is open on it — a destination flips
    /// the root to Advanced, and Simple clears the destination.
    var showsSimple: Bool {
        settingsRoot == .simple && !editingLua
    }

    /// The switch's pick, the one write of the stored root. Simple
    /// edits the loaded profile only, so leaving a stored target
    /// for it goes through the profile switch's discard question.
    func pickRoot(_ root: SettingsRoot) {
        guard root != settingsRoot else { return }
        let apply = { [self] in
            settingsRoot = root
            SettingsRootPreference.write(root, to: preferences)
        }
        guard root == .simple, editingStoredProfile else {
            return apply()
        }
        discardingEdits(
            message: L(
                "discard.switch_profile.message",
                "Switching profiles drops the edits you "
                    + "haven't saved."
            ),
            confirmLabel: L(
                "discard.switch_profile.confirm",
                "Discard & switch"
            )
        ) { [self] in
            selectEditTarget(nil)
            apply()
        }
    }

    /// Leaves Simple through a named door — a "… in Advanced ›"
    /// link, a save-pill row Simple does not draw — for this
    /// window only; the stored choice stays the user's pick.
    func openAdvanced(_ anchor: SettingsAnchor? = nil) {
        settingsRoot = .advanced
        if let anchor { land(on: anchor) }
    }

    /// The tour's landing (#2737 ruling 15): its page while the
    /// stored root is Advanced; Simple's root otherwise.
    func landFromTour(_ destination: SettingsDestination) {
        guard
            SettingsRootPreference.read(from: preferences) == .advanced
        else { return }
        land(on: SettingsAnchor(destination: destination))
    }

    /// What Simple hides that the draft holds: App Rules, every
    /// layer but the default, and Lua bindings across all layers.
    var simpleHiddenCounts: SimpleHiddenCounts {
        SimpleHiddenCounts(
            appRules: appRuleCount,
            layers: config.layers.filter { !$0.isDefault }.count,
            luaBindings: config.layers.flatMap(\.bindings)
                .filter(ShortcutsGates.isLuaBinding).count
        )
    }

    /// What is running: the loaded profile, else the layout that
    /// stands in for one.
    var liveTargetTitle: String {
        if let profile = activeProfile { return profile }
        if let standard = activeStandard {
            return L(
                "profile_header.title.standard",
                "Standard: %1$@",
                standardDisplayName(
                    standard,
                    title: activeStandardTitle
                )
            )
        }
        return L(
            "profile_header.title.transient",
            "Transient layout"
        )
    }

    /// The profile this window edits — Simple's title and the
    /// profile chip's face.
    var editTargetTitle: String { editingProfile ?? liveTargetTitle }
}
