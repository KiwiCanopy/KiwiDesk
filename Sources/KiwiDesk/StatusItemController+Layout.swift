import AppKit
import KiwiDeskCore

extension StatusItemController {
    /// The Layout submenu: flat with one screen, one level deeper
    /// with several (#752).
    func layoutItem() -> NSMenuItem {
        let parent = NSMenuItem(
            title: L("menu.layout", "Layout"),
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("rectangle.3.group")
        // Manual enablement: under the default auto-enable,
        // AppKit re-enables at display time any item whose
        // target responds to its action, discarding the save
        // row's `isEnabled` below (the quick menu's first
        // action-bearing item that must stay disabled). The cost
        // is the other half of the switch — every row here states
        // `isEnabled`, because a nil-action row is no longer
        // disabled for free (#802).
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

    /// One screen's row, carrying its own mode list.
    ///
    /// The checkmark inside answers "what is this screen running
    /// right now", so the submenu doubles as the readout the
    /// menu bar could not give before — a user with three screens
    /// had to click into each one to find out.
    private func screenItem(
        _ screen: LayoutMenuInfo.Screen
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: screen.name,
            action: nil,
            keyEquivalent: ""
        )
        // Stated, not inherited: this menu turned auto-enabling
        // off, so a submenu parent is no longer enabled for free
        // either (#802).
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

    /// "All screens" — the same pick applied to every screen's
    /// shown space at once, which is what plugging in a dock
    /// wants.
    ///
    /// It carries **no checkmark**, deliberately: a tick would
    /// have to mean "every screen is already running this", which
    /// is a different claim from any one screen's mode and would
    /// read as the current state of a thing that has no single
    /// state. The per-screen rows below are where the answer is.
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

    /// Every layout mode, checked against `live`.
    ///
    /// `subtitleWhenDrifted` gates the "not saved to profile"
    /// hint: drift is per space, so it is answered per screen row
    /// rather than once at the top — and the flat menu keeps
    /// answering it for the active space.
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

    /// The save row, unchanged in meaning: it saves the ACTIVE
    /// space's layout to the profile.
    ///
    /// Deliberately not per screen. `savedModeForActiveSpace` and
    /// `persistProfile` are whole-profile operations, so a
    /// per-screen save would be a second feature rather than a
    /// second row — and the profile a save writes to is one
    /// profile whatever screen the user is looking at.
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
            // The INTERSECTION of what the menu offered and what
            // is connected now. Re-reading alone was wrong in one
            // direction and closing over the build alone in the
            // other: a screen unplugged between opening the menu
            // and picking a row must not be written to, and a
            // screen that appeared since must not be silently
            // included in an action the user took against a menu
            // that never listed it. The row carries what it
            // promised; the provider says what still exists.
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
