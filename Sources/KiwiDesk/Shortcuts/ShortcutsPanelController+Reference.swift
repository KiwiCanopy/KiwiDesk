import AppKit
import KiwiDeskCore

/// Shortcuts reference panel data builder (`ShortcutsReferenceBuilder`, #820).
extension ShortcutsPanelController {
    /// Builds shortcuts reference snapshot for active key layer.
    func buildReference() -> ShortcutsReference? {
        let layers: [KeyLayer]
        let activeLayer: String
        let config: GuiConfig
        if let snapshot = core.liveKeybindingSnapshot() {
            layers = snapshot.keyLayers
            activeLayer = snapshot.activeLayerName
            config = core.loadGuiConfig()
        } else if core.isGuiManaged,
            let raw = core.persistedGuiConfig()
        {
            layers = raw.layers
            activeLayer = raw.layers.first?.name ?? KeyLayer.defaultName
            config = raw
        } else {
            return nil
        }
        let layer =
            layers.first { $0.name == activeLayer }
            ?? layers.first
            ?? KeyLayer.defaultLayer
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: config.spaces,
            spaceIcons: config.settings.spaceIcons,
            desktops: core.bindableDesktops(
                in: NativeSpaces.desktopSnapshot()
            ),
            resizeStep: Int(config.settings.resizeStep),
            layerNames: layers.map(\.name)
        )
        return withAppGlyphs(
            reference,
            settings: config.settings
        )
    }

    /// Attaches app font glyphs to reference app shortcuts (#294).
    private func withAppGlyphs(
        _ reference: ShortcutsReference,
        settings: TilingSettings
    ) -> ShortcutsReference {
        let source = settings.appBarStyle.iconSource
        // Allocation early-out only — the authoritative gate
        // lives in the resolver; mapping through it with an
        // image source would just write nils.
        guard source == .appFont else { return reference }
        var out = reference
        out.apps = reference.apps.map { row in
            var row = row
            row.glyph = core.appFont.glyph(
                forAppName: row.label,
                source: source
            )
            return row
        }
        return out
    }
}
