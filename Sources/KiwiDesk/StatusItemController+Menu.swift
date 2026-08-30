import AppKit
import KiwiDeskCore

/// Status bar quick menu builder (#68 §3.10, #802).
extension StatusItemController {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        let profiles = profilesProvider()
        let phase = bootPhase

        var warnings: [NSMenuItem] = []
        if warning {
            let paused = NSMenuItem(
                title: L(
                    "menu.accessibility_paused",
                    "Window Management Paused…"
                ),
                action: #selector(showAccessibilityHelp),
                keyEquivalent: ""
            )
            paused.target = self
            paused.image = symbol("exclamationmark.triangle.fill")
            paused.toolTip = L(
                "menu.accessibility_paused.tooltip",
                "Click to grant Accessibility permission and "
                    + "resume tiling."
            )
            warnings.append(paused)
        }
        if case .scanning = phase {
            let status = NSMenuItem(
                title: Self.startingTitle(for: phase),
                action: nil,
                keyEquivalent: ""
            )
            status.isEnabled = false
            warnings.append(status)
            startingRow = status
        } else {
            startingRow = nil
        }
        if configError {
            let issues = NSMenuItem(
                title: L(
                    "menu.config_issues",
                    "Config Issues…"
                ),
                action: #selector(showConfigIssues),
                keyEquivalent: ""
            )
            issues.target = self
            issues.image = symbol("exclamationmark.triangle.fill")
            warnings.append(issues)
        }
        if !warnings.isEmpty {
            warnings.forEach(menu.addItem)
            menu.addItem(.separator())
        }

        let hasSwitchTarget = profiles.all.contains {
            $0 != profiles.active
                && !profiles.broken.contains($0)
        }
        // Active profile header shown only when alternative targets exist
        // (#324, #36).
        if let active = profiles.active, hasSwitchTarget {
            let current = NSMenuItem.sectionHeader(
                title: L(
                    "menu.active_profile",
                    "Profile: %1$@",
                    active
                )
            )
            menu.addItem(current)
        }
        // Dim rather than hide during boot scanning (#171).
        let layout = layoutItem()
        layout.isEnabled = !phase.isStarting
        menu.addItem(layout)
        if hasSwitchTarget {
            let switcher = switchProfileItem(profiles)
            switcher.isEnabled = !phase.isStarting
            menu.addItem(switcher)
        }

        // App chrome (#326).
        menu.addItem(.separator())
        let shortcutsTitle = L(
            "menu.view_shortcuts",
            "View Shortcuts…"
        )
        let shortcuts = NSMenuItem(
            title: shortcutsTitle,
            action: #selector(showShortcuts(_:)),
            keyEquivalent: ""
        )
        shortcuts.target = self
        shortcuts.image = symbol("keyboard")
        // The status menu is not the app's MainMenu, so its key
        // equivalent is active only while this menu is tracking.
        // Using the native column gives the combo AppKit's dimmed,
        // right-aligned treatment; its duplicate keyboard action
        // is ignored in `showShortcuts` below.
        if let combo = shortcutsComboProvider() {
            Self.applyMenuEquivalent(combo, to: shortcuts)
        }
        menu.addItem(shortcuts)
        let settings = NSMenuItem(
            title: L("menu.settings", "Settings…"),
            action: #selector(openDashboard),
            keyEquivalent: ","
        )
        settings.target = self
        settings.image = symbol("gearshape")
        menu.addItem(settings)

        menu.addItem(.separator())
        menu.addItem(makeUpdatesItem())
        let quit = NSMenuItem(
            title: L("menu.quit", "Quit KiwiDesk"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.image = symbol("power")
        menu.addItem(quit)
    }

    /// The count row's title. One authoring site, because the
    /// row is built on menu open and retitled per chunk while the
    /// menu is up — two spellings of it would drift the moment
    /// either changed.
    ///
    /// The number is last and behind a label
    /// (localization.md ▸ a frame interpolating a COUNT), and the
    /// unit is APPS, matching the tooltip one hover away.
    static func startingTitle(for phase: BootPhase) -> String {
        guard case .scanning(let scanned, let total) = phase else {
            return ""
        }
        return L(
            "menu.starting",
            "Starting up — apps: %1$d of %2$d",
            scanned,
            total
        )
    }

    /// `load_profile` had no quick path before (§3.10): one
    /// submenu entry per saved profile, checkmark on the
    /// active one.
    private func switchProfileItem(
        _ profiles: (
            active: String?, all: [String], broken: Set<String>
        )
    ) -> NSMenuItem {
        let parent = NSMenuItem(
            title: L("menu.switch_profile", "Switch Profile"),
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("square.stack.3d.up")
        let submenu = NSMenu()
        if profiles.all.isEmpty {
            let empty = NSMenuItem(
                title: L(
                    "menu.no_profiles",
                    "No saved profiles"
                ),
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        for name in profiles.all {
            // A broken profile carries no action, so the menu
            // auto-disables it — greyed but still listed (#246).
            let broken = profiles.broken.contains(name)
            let entry = NSMenuItem(
                title: name,
                action: broken
                    ? nil : #selector(loadProfile(_:)),
                keyEquivalent: ""
            )
            entry.target = broken ? nil : self
            entry.state =
                name == profiles.active ? .on : .off
            if broken {
                entry.toolTip = L(
                    "menu.profile_broken",
                    "Can't load — see Config Issues"
                )
            }
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    private static func applyMenuEquivalent(
        _ combo: KeyCombo,
        to item: NSMenuItem
    ) {
        var modifiers: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.control) {
            modifiers.insert(.control)
        }
        if combo.modifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if combo.modifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if combo.modifiers.contains(.command) {
            modifiers.insert(.command)
        }
        guard let key = menuKey(for: combo.keyCode) else { return }
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = modifiers
    }

    private static func menuKey(for code: UInt32) -> String? {
        let special: [UInt32: String] = [
            36: "\r", 76: "\u{3}", 48: "\t", 49: " ",
            51: "\u{8}", 117: "\u{7F}", 53: "\u{1B}",
            123: "\u{F702}", 124: "\u{F703}",
            125: "\u{F701}", 126: "\u{F700}",
            115: "\u{F729}", 119: "\u{F72B}",
            116: "\u{F72C}", 121: "\u{F72D}",
            122: "\u{F704}", 120: "\u{F705}",
            99: "\u{F706}", 118: "\u{F707}",
            96: "\u{F708}", 97: "\u{F709}",
            98: "\u{F70A}", 100: "\u{F70B}",
            101: "\u{F70C}", 109: "\u{F70D}",
            103: "\u{F70E}", 111: "\u{F70F}",
        ]
        return special[code]
            ?? LayoutKeyGlyph.char(for: code)?.lowercased()
    }

    @objc private func openDashboard() {
        onOpenDashboard()
    }

    @objc private func showShortcuts(_ sender: NSMenuItem) {
        // Carbon owns shortcut globally; ignore AppKit's duplicate keyDown
        // event.
        if NSApp.currentEvent?.type == .keyDown { return }
        onShowShortcuts()
    }

    @objc private func showConfigIssues() {
        onShowConfigIssues()
    }

    @objc private func showAccessibilityHelp() {
        onShowAccessibilityHelp()
    }

    @objc private func loadProfile(_ sender: NSMenuItem) {
        onLoadProfile(sender.title)
    }
}
