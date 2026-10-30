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

    /// A layer switch (#603) re-reads what the open panel shows
    /// from the layer: the switch's chords on any side, and the
    /// sheet where it shows.
    func reloadShortcutsIfShown() {
        guard isOpen, let model = currentModel else { return }
        model.chords = liveChords()
        if model.scope == .shortcuts { model.reloadShortcuts() }
    }

    /// Builds the shortcuts reference for the active key layer
    /// (`ShortcutsReferenceBuilder`, #820).
    func buildReference() -> ShortcutsReference? {
        var layers: [KeyLayer]
        let activeLayer: String
        let config: GuiConfig
        var unread: [UnreadChord] = []
        if let snapshot = core.liveKeybindingSnapshot() {
            layers = snapshot.keyLayers
            activeLayer = snapshot.activeLayerName
            config =
                snapshot.isLuaOwned
                ? core.liveShortcutContext() : core.loadGuiConfig()
            if snapshot.isLuaOwned {
                // Recovered bodies arrive as raw Lua; sort the ones
                // the catalog knows into its bands, as Settings ▸
                // Import does (#2482).
                var classified = config
                classified.layers = layers
                KeybindingImportClassifier.classify(&classified)
                layers = classified.layers
                unread = snapshot.unreadChords(in: activeLayer)
            }
        } else if core.isGuiManaged,
            let raw = core.persistedGuiConfig()
        {
            // No live VM, so no load recorded an owner and the
            // file's is the only answer.
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
        // read-only glance, and a layer switch re-reads the sheet
        // (#820, #2246).
        let desktops = NativeSpaces.desktopSnapshot()
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            // Every live Space, so a temporary or held Space's
            // working chord files beside the others, not under
            // Inactive (#1827).
            spaces: core.liveOnlySpaces.shortcutSpaces(
                after: config.spaces
            ),
            spaceIcons: config.settings.spaceIcons,
            desktops: core.bindableDesktops(in: desktops),
            landings: core.desktopLandings(in: desktops),
            resizeStep: Int(config.settings.resizeStep),
            layerNames: layers.map(\.name),
            lenses: core.kiwiVisionLensChoices.map(\.name),
            unread: unread
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
