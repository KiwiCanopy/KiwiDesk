import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The Desktop switch cue (#2142): fed by Core's one payer,
    /// standing down where the shelf would, and following the
    /// Liquid Glass switch through the ⌃⌥K panel's leaf, as the
    /// slow-boot notice does.
    func wireDesktopCue() {
        core.desktopCue.onCue = { [weak self] cue in
            self?.desktopCuePlate.show(cue)
        }
        desktopCuePlate.screenStandsDown = { [weak self] screen in
            self?.core.shelfStandsDown(on: screen) ?? false
        }
        desktopCuePlate.liquidGlass = { [weak self] in
            self?.core.tiler.settings.shortcutPanelLiquidGlass ?? true
        }
    }
}
