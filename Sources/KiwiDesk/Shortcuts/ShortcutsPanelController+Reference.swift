import AppKit
import KiwiDeskCore

/// Builds the panel's content data. Split from
/// `ShortcutsPanelController.swift` (350-line ceiling); `show()`
/// there is the one caller.
extension ShortcutsPanelController {
    /// The shortcuts for the active layer. Nil ONLY when the config
    /// is genuinely owned by `init.lua` (not GUI-managed) — the view
    /// then shows its "managed by init.lua" placeholder.
    ///
    /// Prefers the live, resolved snapshot (what Carbon actually has
    /// installed). When window management is paused — no Accessibility
    /// permission, or bindings not applied yet — there is no snapshot;
    /// for a GUI-managed config we fall back to the CONFIGURED layers
    /// from gui.json so the user still sees their shortcuts (defined,
    /// just not live right now) rather than a misleading placeholder.
    func buildReference() -> ShortcutsReference? {
        let layers: [KeyLayer]
        let activeLayer: String
        let config: GuiConfig
        if let snapshot = core.liveKeybindingSnapshot() {
            // Live: the running engine's spaces match the resolved
            // bindings, so the live-overlaid config is correct.
            layers = snapshot.keyLayers
            activeLayer = snapshot.activeLayerName
            config = core.loadGuiConfig()
        } else if core.isGuiManaged,
            let raw = core.persistedGuiConfig()
        {
            // Paused (no Accessibility): the engine hasn't discovered
            // any spaces, so loadGuiConfig would overlay an EMPTY live
            // space list and misfile every space shortcut into Custom.
            // Read the persisted gui.json directly — it keeps the
            // authored spaces and layers.
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
        // Two-source read: the layers supply the bindings; the config
        // supplies only spaces / icons / step, used to *generate
        // candidate preset rows* that are then intersected with the
        // actual bindings. A transient disagreement (space or step
        // edited but not yet re-applied) can only misfile a binding
        // — never hide or invent one — which stays safe for a
        // read-only glance panel. Since #820 the misfile can land
        // in Inactive as well as Custom, and that band's caption
        // ASSERTS the Space has left the list; the window is the
        // beat between a space edit and its apply, and it closes
        // itself, exactly as the Custom misfile does.
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: config.spaces,
            spaceIcons: config.settings.spaceIcons,
            resizeStep: Int(config.settings.resizeStep),
            layerNames: layers.map(\.name)
        )
        return withAppGlyphs(
            reference,
            settings: config.settings
        )
    }

    /// #294: when the bar renders App Font glyphs, the Apps
    /// band leads with the same glyph; apps without one keep
    /// their bundle icon. Deliberately keyed on the GLOBAL
    /// symbol style — the panel spans all layouts, so a
    /// Lua-only per-layout override can't (and shouldn't)
    /// steer it.
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
