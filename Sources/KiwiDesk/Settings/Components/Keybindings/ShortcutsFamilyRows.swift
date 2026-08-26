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
/// A family with no keybinding rows of its own returns `nil`:
/// the renderer draws that container by hand (the layer strip and
/// its icon row, the app list, the raw-Lua list and its Import
/// action), and the census still places it so search and the
/// placement table can see it. `nil` means "this family is not a
/// NavRow list", never "unhandled" — and WHICH families may
/// answer it is enumerated in `ShortcutsCensusRenderTests`, not
/// counted here, because a count in prose is a second copy that
/// rots (this one shipped saying four over five cases).
@MainActor
struct ShortcutsFamilyRows {
    /// The spaces the per-space families expand over.
    let spaces: [SpaceID]
    /// Space icons, recognition sugar on the per-space rows.
    let icons: [SpaceID: String]
    /// Which Desktops each per-Desktop family expands over,
    /// and which of those are away — the offer AND the
    /// capability in one value, so a macOS without the Desktop
    /// bridge draws no Desktop rows rather than rows that would
    /// refuse. `KiwiCore.bindableDesktops(in:)` is where the
    /// capability joins the topology;
    /// `KeybindingCatalog.desktopOffer` widens that per family
    /// by the Desktops those bindings already name.
    let desktops: KeybindingCatalog.DesktopOffer
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

    /// The rows a key contributes once interleaving is applied:
    /// its own, or — when it LEADS an interleaved run — the run's
    /// columns zipped per instance. A non-leading member of a run
    /// contributes nothing; the leader already emitted its rows.
    ///
    /// Here rather than in the view because interleaving is a
    /// statement about ROWS, which is what this type owns; the
    /// view's job is to draw whatever it is handed. That it also
    /// becomes reachable from a test is a consequence, not the
    /// reason — set equality cannot see instance order, so this
    /// is the only place a guard could hold it.
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
        // Zip by instance index. Ragged columns cannot happen —
        // every family in a run expands over the same instance
        // list — but truncating to the shortest is the safe read
        // if one ever does, rather than trapping on a subscript.
        let depth = columns.map(\.count).min() ?? 0
        return (0..<depth).flatMap { row in
            columns.map { $0[row] }
        }
    }
}
