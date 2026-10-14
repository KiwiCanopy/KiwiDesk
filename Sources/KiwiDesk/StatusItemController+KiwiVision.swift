import AppKit
import KiwiDeskCore

/// The quick menu's KiwiVision row (#2103): a checkmark that
/// mirrors the mode, its live chord in the native column.
extension StatusItemController {
    /// Greyed while `inert`: booting, or tiling not started.
    func makeKiwiVisionItem(inert: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: L("menu.kiwivision", "KiwiVision"),
            action: #selector(toggleKiwiVision),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = !inert
        item.image = symbol("eyeglasses")
        item.state = kiwiVisionProvider() ? .on : .off
        if let combo = kiwiVisionComboProvider() {
            Self.applyMenuEquivalent(combo, to: item)
        }
        return item
    }

    @objc func toggleKiwiVision() {
        // Carbon owns a bound chord globally; AppKit's duplicate
        // keyDown is dropped.
        if menuActionIsKeyDown() { return }
        onToggleKiwiVision()
    }
}
