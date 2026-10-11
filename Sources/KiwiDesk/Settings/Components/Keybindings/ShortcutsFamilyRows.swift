import KiwiDeskCore

/// Expands a keybinding family into renderable command rows
/// (#678 Phase 3). The switch is exhaustive over `ShortcutsKey`
/// on purpose: a census family without an expansion fails to
/// compile. `nil` means "not a NavRow list" (a bespoke container),
/// never "unhandled" — WHICH families may answer nil is enumerated
/// in `ShortcutsCensusRenderTests`, not counted here.
@MainActor
struct ShortcutsFamilyRows {
    /// Active spaces for per-space family expansion.
    let spaces: [SpaceID]
    /// Space recognition icons.
    let icons: [SpaceID: String]
    /// The live Spaces the profile does not hold (#1827), drawn
    /// after `spaces` in the per-Space families: temporary, then
    /// held.
    var liveOnly: [LiveOnlySpace] = []
    /// Desktop availability offer (`KiwiCore.bindableDesktops(in:)`,
    /// `KeybindingCatalog.desktopOffer`).
    let desktops: KeybindingCatalog.DesktopOffer
    /// Configurable resize step in points (#58).
    let resizeStep: Int
    /// Available layer names and active editing layer.
    let layerNames: [String]
    let currentLayer: String

    func rows(for key: SettingKey) -> [NavCommand]? {
        guard case .shortcuts(let family) = key else {
            // Only `ShortcutsKey` carries keybinding rows; a
            // key from another area is drawn by its own card.
            return nil
        }
        return rows(for: family)
    }

    private func rows(for family: ShortcutsKey) -> [NavCommand]? {
        switch family {
        case .focusDir:
            return KeybindingCatalog.focusDirections
        case .spaceStep:
            return KeybindingCatalog.spaceStepRows
        case .spaceHistoryStep:
            return KeybindingCatalog.spaceHistoryRows
        case .goToSpace:
            return perSpace(KeybindingCatalog.goToSpace)
        case .swapDir:
            return KeybindingCatalog.swapDirections
        case .moveWindowToTrack:
            return KeybindingCatalog.moveToTrackRows
        case .swapWithTrack:
            return KeybindingCatalog.trackSwapRows
        case .moveToSpace:
            return perSpace(KeybindingCatalog.moveToSpaceRows)
        case .moveToSpaceFollow:
            return perSpace(KeybindingCatalog.moveToSpaceFollowRows)
        case .focusDesktop:
            return KeybindingCatalog.goToDesktop(
                desktops.desktops,
                absent: desktops.absent
            )
        case .moveToDesktop:
            return KeybindingCatalog.moveToDesktopRows(
                desktops.desktops,
                absent: desktops.absent
            )
        case .moveToDesktopFollow:
            return KeybindingCatalog.moveToDesktopFollowRows(
                desktops.desktops,
                absent: desktops.absent
            )
        case .growWidth:
            return [resizeRow(.growWidth)]
        case .shrinkWidth:
            return [resizeRow(.shrinkWidth)]
        case .growHeight:
            return [resizeRow(.growHeight)]
        case .shrinkHeight:
            return [resizeRow(.shrinkHeight)]
        case .toggleFloating:
            return [KeybindingCatalog.toggleFloating]
        case .toggleSticky:
            return [KeybindingCatalog.toggleSticky]
        case .toggleDisplaySticky:
            return [KeybindingCatalog.toggleDisplaySticky]
        case .showShortcuts:
            return [KeybindingCatalog.showShortcuts]
        case .openSettings:
            return [KeybindingCatalog.openSettings]
        case .switchToLayer:
            return
                layerNames
                .filter { $0 != currentLayer }
                .map(KeybindingCatalog.switchLayerCommand)
        case .layers, .layersIcon, .layersReach, .openApplications,
            .advanced,
            .`import`, .restoreDefaults, .scrollPan, .scrollLongSwipes,
            .scrollStepDistance, .scrollNaturalTrackpad,
            .scrollNaturalMouse, .scrollSpaceStep, .spaceHistory:
            return nil
        }
    }

    /// A per-Space family over the profile's Spaces, then the
    /// live-only ones wearing their chip.
    private func perSpace(
        _ make: ([SpaceID], [SpaceID: String]) -> [NavCommand]
    ) -> [NavCommand] {
        let extra = liveOnly.shortcutOrder.filter {
            !spaces.contains($0.id)
        }
        var icons = icons
        for space in extra {
            if let icon = space.icon { icons[space.id] = icon }
        }
        var rows = make(spaces + extra.map(\.id), icons)
        for (offset, space) in extra.enumerated() {
            rows[spaces.count + offset].liveOnly = space.kind
        }
        return rows
    }

    /// Every Space a per-Space binding can reach now: the
    /// profile's and the live-only ones (#1827).
    var liveSpaces: [SpaceID] { liveOnly.shortcutSpaces(after: spaces) }

    private func resizeRow(
        _ row: KeybindingCatalog.ResizeRow
    ) -> NavCommand {
        KeybindingCatalog.resizeRow(row, step: resizeStep)
    }

    /// Evaluates rendered rows accounting for interleaved shortcut runs
    /// (`ShortcutsRowOrder`).
    func renderedRows(for key: SettingKey) -> [NavCommand] {
        if ShortcutsRowOrder.isInterleavedFollower(key) {
            return []
        }
        guard
            let run = ShortcutsRowOrder.interleavedRun(
                startingAt: key
            )
        else { return rows(for: key) ?? [] }
        let columns = run.map { rows(for: $0) ?? [] }
        // Ragged columns cannot happen — every family in a run
        // expands over the same instance list — but truncating to
        // the shortest beats trapping on a subscript if one does.
        let depth = columns.map(\.count).min() ?? 0
        return (0..<depth).flatMap { row in
            columns.map { $0[row] }
        }
    }
}
