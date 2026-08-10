import KiwiDeskCore

/// The stored-label → localized-name mapping the conflict
/// banner narrates through (#96: `KeyBinding.label` is the
/// stable ENGLISH canonical the classifier matches on, and a
/// banner interpolating it verbatim shipped "Focus window to
/// the left" inside a German sentence — owner, 2026-08-10).
extension KeybindingCatalog {
    /// The localized display name for a persisted binding
    /// label, resolved over the same roster the import
    /// classifier recognises. A label the roster does not
    /// carry — an app name, a custom row, a resize row from a
    /// retired step — returns unchanged: an app name needs no
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
        commands += [
            toggleFloating, makeFloating, toggleSticky,
            toggleDisplaySticky, makeSticky,
            makeDisplaySticky, makeUnsticky, showShortcuts,
        ]
        guard
            let match = commands.first(where: {
                $0.label == label
            })
        else { return label }
        return match.resolvedLabel
    }
}
