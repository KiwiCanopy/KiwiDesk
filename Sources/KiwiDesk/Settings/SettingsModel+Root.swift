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
    /// Picking the root already on screen still stores it: after a
    /// landing the screen shows Advanced while Simple is stored.
    func pickRoot(_ root: SettingsRoot) {
        let apply = { [self] in
            settingsRoot = root
            SettingsRootPreference.write(root, to: preferences)
        }
        guard root == .simple, settingsRoot != .simple,
            editingStoredProfile
        else { return apply() }
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

    /// A fresh open on Simple edits the loaded profile: a stored
    /// target an Advanced page picked does not outlive the close,
    /// which already reverted its draft.
    func settleSimpleTarget() {
        if settingsRoot == .simple, editingStoredProfile {
            selectEditTarget(nil)
        }
    }

    /// Leaves Simple through a named door — a "… in Advanced ›"
    /// link — for this window only; the stored choice stays the
    /// user's pick. With an anchor the landing's own destination
    /// flips the root, so no Advanced Home shows in between.
    func openAdvanced(_ anchor: SettingsAnchor? = nil) {
        guard let anchor else { return settingsRoot = .advanced }
        land(on: anchor)
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
