import AppKit
import KiwiDeskCore

extension StatusItemController {
    func layoutItem() -> NSMenuItem {
        let parent = NSMenuItem(
            title: L("menu.layout", "Layout"),
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("square.split.2x2")
        let submenu = NSMenu()
        let info = layoutInfoProvider()
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
            if isCurrent, info.activeProfileName != nil,
                info.activeMode != info.savedModeForActiveSpace
            {
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
            saveEntry.isEnabled =
                info.activeMode != info.savedModeForActiveSpace
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
