import AppKit
import KiwiDeskCore

/// The key panel's Shortcuts side (#2246): the sheet it reads, and
/// its bridge into Settings.
extension JumpPanelController {
    func wireShortcuts(_ model: JumpModel) {
        model.loadShortcuts = { [weak self] in self?.buildReference() }
        // No distrust: a close arms none, and the next own report
        // is Settings coming forward (#952).
        model.onEditShortcuts = { [weak self] in
            guard let self, self.dismiss(distrusting: false) else { return }
            self.onEditShortcuts()
        }
    }

    /// Re-reads the sheet on a layer switch (#603), where it shows.
    func reloadShortcutsIfShown() {
        guard isOpen, let model = currentModel, model.scope == .shortcuts
        else { return }
        model.reloadShortcuts()
    }

    /// Builds the shortcuts reference for the active key layer
    /// (`ShortcutsReferenceBuilder`, #820).
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
            // Paused (no Accessibility): the engine discovered no
            // spaces, so loadGuiConfig would overlay an EMPTY live
            // space list and misfile every space shortcut into
            // Custom — read the persisted gui.json directly.
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
        // Two-source read: layers supply bindings; config supplies
        // spaces/icons/step for candidate rows. A transient
        // disagreement can only MISFILE a binding (into Inactive
        // or Custom), never hide or invent one — safe for a
        // read-only glance panel, and the window closes itself on
        // the next apply (#820).
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            // Every live Space, so a temporary or held Space's
            // working chord files beside the others, not under
            // Inactive (#1827).
            spaces: core.liveOnlySpaces.shortcutSpaces(
                after: config.spaces
            ),
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
        let source = settings.kiwishelf.iconSource
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
