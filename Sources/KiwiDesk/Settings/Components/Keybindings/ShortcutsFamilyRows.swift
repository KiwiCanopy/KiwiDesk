import KiwiDeskCore

/// Expands a keybinding FAMILY into the rows it renders (#678
/// Phase 3).
///
/// The census records settings, not rows: `focusDir` is one case
/// and puts four rows on screen, `goToSpace` is one case and puts
/// one row per live space. That asymmetry is the reason the
/// Shortcuts area cannot render straight off an order list the
/// way Bars and Colours do — a `ForEach` over `SettingKey` there
/// yields one control per key, and here it yields a variable
/// number. This type is the missing step, and keeping it separate
/// from `ShortcutsRowOrder` is deliberate: the order list answers
/// *where does this family sit*, this answers *what does it draw*,
/// and `ShortcutsCensusRenderTests` pins each against the census
/// independently.
///
/// The switch is exhaustive over `ShortcutsKey` on purpose. A
/// family added to the census fails to compile here until it is
/// given an expansion, which is a stronger net than the render
/// guard alone — the guard catches a family missing from an order
/// list, the compiler catches one missing from the expansion.
///
/// The four families with no keybinding rows of their own return
/// `nil`: they are containers the renderer draws by hand (the
/// layer strip, the icon row, the app list, the raw-Lua list) and
/// the census places them so search and the placement table can
/// still see them. `nil` means "this family is not a NavRow
/// list", never "unhandled".
@MainActor
struct ShortcutsFamilyRows {
    /// The spaces the per-space families expand over.
    let spaces: [SpaceID]
    /// Space icons, recognition sugar on the per-space rows.
    let icons: [SpaceID: String]
    /// The configurable resize step (#58) baked into the resize
    /// rows' Lua, so the recorded binding matches the catalog
    /// byte-for-byte.
    let resizeStep: Int
    /// Every defined layer name, and the one being edited — the
    /// switch rows expand to the OTHERS.
    let layerNames: [String]
    let currentLayer: String

    func rows(for key: SettingKey) -> [NavCommand]? {
        guard case .shortcuts(let family) = key else {
            // Only `ShortcutsKey` cases carry keybinding rows.
            // `.behaviour(.resizeFeedback)` shares the Size &
            // float container but is an ordinary toggle, drawn
            // by the card rather than expanded here.
            return nil
        }
        return rows(for: family)
    }

    private func rows(for family: ShortcutsKey) -> [NavCommand]? {
        switch family {
        case .focusDir:
            return KeybindingCatalog.focusDirections
        case .goToSpace:
            return spaces.isEmpty
                ? []
                : KeybindingCatalog.goToSpace(spaces, icons: icons)
        case .swapDir:
            return KeybindingCatalog.swapDirections
        case .moveWindowToTrack:
            return KeybindingCatalog.moveToTrackRows
        case .swapWithTrack:
            return KeybindingCatalog.trackSwapRows
        case .moveToSpace:
            return KeybindingCatalog.moveToSpaceRows(
                spaces,
                icons: icons
            )
        case .moveToSpaceFollow:
            return KeybindingCatalog.moveToSpaceFollowRows(
                spaces,
                icons: icons
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
        case .switchToLayer:
            return
                layerNames
                .filter { $0 != currentLayer }
                .map(KeybindingCatalog.switchLayerCommand)
        case .layers, .layersIcon, .openApplications, .advanced,
            .`import`:
            return nil
        }
    }

    private func resizeRow(
        _ row: KeybindingCatalog.ResizeRow
    ) -> NavCommand {
        KeybindingCatalog.resizeRow(row, step: resizeStep)
    }
}
