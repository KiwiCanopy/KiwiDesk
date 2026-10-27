import KiwiDeskCore

/// Resolves Shortcuts census gates (#678 Phase 3). This area's
/// gates SURFACE rather than grey — non-nil means "not yet at
/// rest" (withheld behind the offer), with no inline sentence —
/// save the layout plate's switch, which greys with General's
/// Lua-owned sentence (#2144). `LayersCard` asks this
/// rather than re-deriving — a renderer whose predicate silently
/// disagreed once hid a user's own configured layers
/// (`ShortcutsGateTests`).
struct ShortcutsGates {
    let config: GuiConfig
    /// `SettingsModel.guiManaged`; read by the plate switch alone,
    /// which writes `gui.json` at once (#2144).
    var guiManaged = true
    /// `SettingsModel.editingStoredProfile`; read by the Shortcuts use
    /// switch alone, whose Save must write the shared rows (#2460).
    var editingStoredProfile = false

    /// Reason why a Shortcuts setting is withheld or gated.
    enum InertReason: Hashable, CaseIterable {
        /// Only default layer configured (`.layersExist`).
        case onlyDefaultLayer
        /// No Track space and no Track verb bound (`.trackInUse`).
        case trackUnused
        /// `init.lua` owns the config, so the app-wide plate switch
        /// has no store to write (`.luaOwnsConfig`, #2144).
        case appWideLuaOwned
        /// A saved profile other than the loaded one is being
        /// edited, so the Shortcuts use switch has no shared rows to
        /// write (#2460).
        case storedProfilePage
    }

    /// Evaluates inert reason for setting key.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .shortcuts(.layersIcon), .shortcuts(.layersReach),
            .shortcuts(.switchToLayer):
            // `default` always exists, so a SECOND entry is what
            // "the user configured a layer" means — presence, not
            // a count.
            return config.layers.count > 1 ? nil : .onlyDefaultLayer
        case .shortcuts(.moveWindowToTrack),
            .shortcuts(.swapWithTrack):
            return trackIsUsed ? nil : .trackUnused
        case .shortcuts(.modeCue), .shortcuts(.desktopCue),
            .shortcuts(.hyperKey), .shortcuts(.modifierSides):
            return guiManaged ? nil : .appWideLuaOwned
        case .shortcuts(.shortcutBase):
            guard guiManaged else { return .appWideLuaOwned }
            return editingStoredProfile ? .storedProfilePage : nil
        default:
            assertionFailure(
                "ShortcutsGates does not own \(key.id)"
            )
            return nil
        }
    }

    /// Whether the user has a layer to CHOOSE between — the one
    /// spelling of that question (#1127). Written against the
    /// case rather than against nil: a second `InertReason`
    /// arriving for some other cause would otherwise stop the
    /// preview caption and the header naming their layer, for a
    /// reason that has nothing to do with how many there are.
    var layersExist: Bool {
        inertReason(for: .shortcuts(.switchToLayer))
            != .onlyDefaultLayer
    }

    /// Whether any layer records a move to a Desktop (#2655): the
    /// macOS Desktops drawer's hold-open, not a census gate. Go to
    /// Desktop is seeded, so it never opens the drawer.
    var desktopMovesBound: Bool {
        config.layers.flatMap(\.bindings)
            .contains(where: KeybindingCatalog.recordsDesktopMove)
    }

    /// Whether `layer` carries a Lua binding: the Lua bindings
    /// drawer's hold-open, not a census gate (#2654). Per layer,
    /// since the drawer lists the selected layer's rows alone.
    func luaBindingsExist(in layer: String) -> Bool {
        config.layers.first { $0.name == layer }?.bindings
            .contains(where: Self.isLuaBinding) ?? false
    }

    /// A row the Lua bindings drawer lists — the one spelling its
    /// rows and its hold-open share.
    static func isLuaBinding(_ binding: KeyBinding) -> Bool {
        binding.kind == .custom
    }

    /// Whether the Track layout is in play (#1440): a Track
    /// space in the config this window edits, or a Track verb
    /// recorded in any layer.
    var trackInUse: Bool {
        inertReason(for: .shortcuts(.moveWindowToTrack))
            != .trackUnused
    }

    private var trackIsUsed: Bool {
        !LayoutUsage.spaces(on: .track, in: config).isEmpty
            || config.layers.flatMap(\.bindings)
                .contains(where: KeybindingCatalog.recordsTrack)
    }

    /// Gated keys resolved directly from `GuiConfig`
    /// (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .shortcuts(.layersIcon),
        .shortcuts(.layersReach),
        .shortcuts(.switchToLayer),
        .shortcuts(.moveWindowToTrack),
        .shortcuts(.swapWithTrack),
        .shortcuts(.modeCue),
        .shortcuts(.desktopCue),
        .shortcuts(.hyperKey),
        .shortcuts(.modifierSides),
        .shortcuts(.shortcutBase),
    ]

    /// Gated keys resolved dynamically in view state: Import's
    /// and Restore Defaults' gates are live-editor questions no
    /// saved `GuiConfig` can answer, so `ShortcutsHeader` keeps
    /// them. Naming them keeps the gap deliberate.
    static let resolvedElsewhere: Set<SettingKey> = [
        .shortcuts(.`import`),
        .shortcuts(.restoreDefaults),
    ]
}
