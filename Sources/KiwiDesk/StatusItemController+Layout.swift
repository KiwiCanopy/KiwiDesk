import AppKit
import KiwiDeskCore

extension StatusItemController {
    /// Builds Layout submenu, nesting per-screen when multiple displays exist
    /// (#752, #802).
    func layoutItem() -> NSMenuItem {
        let parent = NSMenuItem(
            title: L("menu.layout", "Layout"),
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("rectangle.3.group")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let info = layoutInfoProvider()
        if info.nestsPerScreen {
            submenu.addItem(
                everyScreenItem(info.orderedScreens)
            )
            submenu.addItem(.separator())
            for screen in info.orderedScreens {
                submenu.addItem(screenItem(screen))
            }
        } else {
            addModeRows(
                to: submenu,
                live: info.activeMode,
                drifted: info.activeSpaceHasDrifted,
                scope: .activeSpace
            )
        }
        addSaveRow(to: submenu, info: info)
        parent.submenu = submenu
        return parent
    }

    /// Single screen submenu item with active mode indication (#802).
    private func screenItem(
        _ screen: LayoutMenuInfo.Screen
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: screen.name,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = true
        let modes = NSMenu()
        modes.autoenablesItems = false
        addModeRows(
            to: modes,
            live: screen.mode,
            drifted: screen.hasDrifted,
            scope: .space(screen.space),
            subtitleWhenDrifted: true
        )
        item.submenu = modes
        return item
    }

    /// Submenu item targeting all connected screens simultaneously.
    private func everyScreenItem(
        _ screens: [LayoutMenuInfo.Screen]
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: L("menu.layout.all_screens", "All Screens"),
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = true
        let modes = NSMenu()
        modes.autoenablesItems = false
        addModeRows(
            to: modes,
            live: nil,
            drifted: false,
            scope: .everyScreen(asBuilt: screens.map(\.space))
        )
        item.submenu = modes
        return item
    }

    /// Populates layout mode items with current selection checkmarks.
    private func addModeRows(
        to menu: NSMenu,
        live: LayoutMode?,
        drifted: Bool,
        scope: LayoutMenuTarget.Scope,
        subtitleWhenDrifted: Bool = true
    ) {
        for mode in LayoutMode.allCases {
            let entry = NSMenuItem(
                title: mode.displayName,
                action: #selector(setLayoutMode(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.image = symbol(mode.glyph)
            entry.representedObject = LayoutMenuTarget(
                mode: mode,
                scope: scope
            )
            entry.isEnabled = true
            let isCurrent = (mode == live)
            entry.state = isCurrent ? .on : .off
            if isCurrent, drifted, subtitleWhenDrifted {
                if #available(macOS 14.4, *) {
                    entry.subtitle = L(
                        "menu.layout.unsaved",
                        "not saved to profile"
                    )
                }
            }
            menu.addItem(entry)
        }
    }

    /// Save row persisting active space layout into active profile
    /// (`persistProfile`).
    private func addSaveRow(
        to menu: NSMenu,
        info: LayoutMenuInfo
    ) {
        guard info.activeProfileName != nil else { return }
        menu.addItem(.separator())
        let saveEntry = NSMenuItem(
            title: L(
                "menu.layout.save",
                "Save Current Layout to Profile"
            ),
            action: #selector(saveLayoutToProfile(_:)),
            keyEquivalent: ""
        )
        saveEntry.target = self
        saveEntry.isEnabled = info.activeSpaceHasDrifted
        menu.addItem(saveEntry)
    }

    @objc func setLayoutMode(_ sender: NSMenuItem) {
        guard
            let target = sender.representedObject
                as? LayoutMenuTarget
        else { return }
        switch target.scope {
        case .activeSpace:
            onSetLayoutMode(target.mode, nil)
        case .space(let id):
            onSetLayoutMode(target.mode, id)
        case .everyScreen(let asBuilt):
            let live = Set(layoutInfoProvider().screens.map(\.space))
            for space in asBuilt where live.contains(space) {
                onSetLayoutMode(target.mode, space)
            }
        }
    }

    @objc func saveLayoutToProfile(_ sender: NSMenuItem) {
        onSaveLayoutToProfile()
    }
}
