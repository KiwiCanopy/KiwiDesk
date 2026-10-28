import KiwiDeskCore

/// The Simple / Advanced roots (#2737) and the facts Simple's
/// header draws.
extension SettingsModel {
    /// Whether the window draws Simple's page: its root, outside
    /// every Advanced page and the Lua editor.
    var showsSimple: Bool {
        settingsRoot == .simple && destination == nil && !editingLua
    }

    /// Leaves Simple for an Advanced page — a "… in Advanced ›"
    /// link, a save-pill row Simple does not draw. Setting
    /// `destination` flips the surface itself; this names the act.
    func openAdvanced(_ destination: SettingsDestination? = nil) {
        settingsRoot = .advanced
        if let destination { self.destination = destination }
    }

    /// What Simple hides that the draft holds: App Rules, every
    /// layer but the default, and Lua bindings across all layers.
    var simpleHiddenCounts: SimpleHiddenCounts {
        SimpleHiddenCounts(
            appRules: config.appRules.count
                + config.floatRules.count,
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
