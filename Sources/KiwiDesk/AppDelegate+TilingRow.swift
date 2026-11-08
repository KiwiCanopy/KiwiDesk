import AppKit
import KiwiDeskCore

/// The quick menu's tiling row (#3008), read fresh on each open.
extension AppDelegate {
    func wireTilingRow(_ statusItem: StatusItemController) {
        statusItem.tilingOffProvider = { [weak self] in
            guard let core = self?.core,
                let space = core.activeSpace?.id
            else { return nil }
            return core.isTilingOff(space)
        }
        statusItem.tilingComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(
                core: self.core,
                lua: KeybindingCatalog.toggleTiling.lua
            )
        }
        statusItem.onToggleTiling = { [weak self] in
            self?.core.withUserMotion {
                _ = self?.core.execute("toggle_tiling")
            }
        }
    }
}
