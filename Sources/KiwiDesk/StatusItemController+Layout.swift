import AppKit
import KiwiDeskCore

extension StatusItemController {
    func layoutItem() -> NSMenuItem {
        let parent = NSMenuItem(
            title: L("menu.layout", "Layout"),
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("rectangle.3.group")
        let submenu = NSMenu()
        // Manual enablement: under the default auto-enable,
        // AppKit re-enables at display time any item whose
        // target responds to its action, discarding the save
        // row's `isEnabled` below (the quick menu's first
        // action-bearing item that must stay disabled).
        submenu.autoenablesItems = false
        let info = layoutInfoProvider()
        // Drift is only claimed when the saved mode is *known*
        // (nil = no profile or unreadable JSON — no phantom
        // subtitle, no enabled save row).
        let drifted =
            info.activeMode != nil
            && info.savedModeForActiveSpace != nil
            && info.activeMode != info.savedModeForActiveSpace
        for mode in LayoutMode.allCases {
            let entry = NSMenuItem(
                title: mode.displayName,
                action: #selector(setLayoutMode(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.image = symbol(mode.glyph)
            entry.representedObject = mode.rawValue
            let isCurrent = (mode == info.activeMode)
            entry.state = isCurrent ? .on : .off
            if isCurrent, drifted {
                if #available(macOS 14.4, *) {
                    entry.subtitle = L(
                        "menu.layout.unsaved",
                        "not saved to profile"
                    )
                }
            }
            submenu.addItem(entry)
        }
        if info.activeProfileName != nil {
            submenu.addItem(.separator())
            let saveEntry = NSMenuItem(
                title: L(
                    "menu.layout.save",
                    "Save Current Layout to Profile"
                ),
                action: #selector(saveLayoutToProfile(_:)),
                keyEquivalent: ""
            )
            saveEntry.target = self
            saveEntry.isEnabled = drifted
            submenu.addItem(saveEntry)
        }
        parent.submenu = submenu
        return parent
    }

    @objc func setLayoutMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
            let mode = LayoutMode(rawValue: raw)
        else { return }
        onSetLayoutMode(mode)
    }

    @objc func saveLayoutToProfile(_ sender: NSMenuItem) {
        onSaveLayoutToProfile()
    }
}
