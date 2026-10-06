import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The slow-boot notice's reads (#1715): it stands down while
    /// the tour owns the screen and where the shelf would, follows
    /// the Liquid Glass switch through the ⌃⌥K panel's leaf, and
    /// anchors on the status item.
    func wireBootNotice() {
        bootNotice.tourShowing = { [weak self] in
            self?.onboardingWindow?.isVisible == true
        }
        bootNotice.screenStandsDown = { [weak self] screen in
            self?.core.standsDown(on: screen) ?? false
        }
        bootNotice.liquidGlass = { [weak self] in
            self?.core.tiler.settings.shortcutPanelLiquidGlass ?? true
        }
        bootNotice.statusButton = { [weak self] in
            self?.statusItem?.anchorButton
        }
    }
}
