import KiwiDeskCore

/// The stored-label → localized-name mapping the conflict
/// banner narrates through (#96: `KeyBinding.label` is the
/// stable ENGLISH canonical the classifier matches on, and a
/// banner interpolating it verbatim shipped "Focus window to
/// the left" inside a German sentence — owner, 2026-08-10).
extension KeybindingCatalog {
    /// The localized display name for a persisted binding
    /// label. The roster is the classifier's own, piece by
    /// piece: the navigation groups, the per-layer switches,
    /// the current-step resize rows (their labels are
    /// step-independent — "Grow width" — so retired-step rows
    /// resolve too), `stepFreeCommands`, the one shared copy of
    /// the float/sticky bracket, and the Desktop rows.
    ///
    /// The Desktop half is read off the BINDINGS rather than
    /// the config, which records no Desktops — and never off a
    /// live list, because the banner must still name a row
    /// whose screen is unplugged. Whatever the classifier can
    /// assign, this roster must translate back (the invariant
    /// `KeybindingImportClassifier.navigationLabels` states),
    /// and the classifier assigns Desktop rows by shape, which
    /// no live list bounds. A label outside it —
    /// an app name, a custom row, a deleted space's or layer's
    /// row — returns unchanged: an app name needs no
    /// translation and a custom label is the user's own text.
    @MainActor static func localizedLabel(
        for label: String,
        config: GuiConfig
    ) -> String {
        guard !label.isEmpty else { return label }
        var commands = navigationGroups(spaces: config.spaces)
            .flatMap(\.commands)
        commands += config.layers.map {
            switchLayerCommand($0.name)
        }
        commands += resizeAndFloat(
            step: Int(config.settings.resizeStep)
        )
        commands += stepFreeCommands
        let desktops = desktopOffer(
            live: [],
            bindings: config.layers.flatMap(\.bindings)
        )
        commands += goToDesktop(desktops.focus)
        commands += moveToDesktop(desktops.move)
        guard
            let match = commands.first(where: {
                $0.label == label
            })
        else { return label }
        return match.resolvedLabel
    }
}
