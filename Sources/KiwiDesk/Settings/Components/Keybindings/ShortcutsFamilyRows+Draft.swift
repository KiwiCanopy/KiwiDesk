import KiwiDeskCore

extension ShortcutsFamilyRows {
    /// Family-to-rows expansion built from the draft, for the
    /// Shortcuts page and Simple's cards alike (#2737). The Desktop
    /// list reads EVERY layer's bindings, not `layer`'s: a row
    /// existing only while its layer is selected would vanish from
    /// under the duplicate block's "Go to", which may point into
    /// another layer.
    @MainActor static func ofDraft(
        _ model: SettingsModel,
        layer: String
    ) -> ShortcutsFamilyRows {
        let bindings = model.config.layers.flatMap(\.bindings)
        return ShortcutsFamilyRows(
            spaces: model.config.spaces,
            icons: model.config.settings.spaceIcons,
            liveOnly: model.liveOnlyShortcutSpaces,
            desktops: KeybindingCatalog.desktopOffer(
                live: model.bindableDesktops,
                bindings: bindings
            ),
            resizeStep: Int(model.config.settings.resizeStep),
            layerNames: model.config.layers.map(\.name),
            currentLayer: layer,
            lenses: KeybindingCatalog.lensOffer(
                stored: model.draftLenses.map(\.name),
                bindings: bindings
            )
        )
    }
}
