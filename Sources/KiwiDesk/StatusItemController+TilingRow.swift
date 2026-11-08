import AppKit
import KiwiDeskCore

/// The quick menu's "Tiling Off for This Space" check row (#3008),
/// carrying the live ⌃⌥T. Copy says "tiling off", never "paused":
/// "Window Management Paused…" is the Accessibility stop.
extension StatusItemController {
    /// The row, or nil while no Space can be toggled (booting, idle).
    func makeTilingItem() -> NSMenuItem? {
        guard let off = tilingOffProvider() else { return nil }
        let item = NSMenuItem(
            title: L("menu.tiling_off", "Tiling Off for This Space"),
            action: #selector(toggleTilingFromMenu(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = symbol("pause")
        item.state = off ? .on : .off
        item.isEnabled = true
        if let combo = tilingComboProvider() {
            combo.applyMenuEquivalent(
                to: item,
                layoutChar: LayoutKeyGlyph.char
            )
        }
        return item
    }

    @objc private func toggleTilingFromMenu(_ sender: NSMenuItem) {
        // The menu's own key equivalent duplicates the hotkey.
        if KeyCombo.isCarbonTwin(
            of: tilingComboProvider(),
            event: menuKeyDown()
        ) {
            return
        }
        onToggleTiling()
    }
}
