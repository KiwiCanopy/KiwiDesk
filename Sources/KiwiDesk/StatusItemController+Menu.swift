import AppKit
import KiwiDeskCore

/// The quick menu (#68 §3.10): rebuilt on every open so the
/// profile list and the conditional warning rows are always
/// current. The icon state machine lives in the main
/// `StatusItemController` file.
extension StatusItemController {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        // Every row below states its own `isEnabled` (#802): with
        // AppKit's auto-enabling on, a row is enabled iff its
        // action validates, so a row that WORKS cannot be greyed
        // for a reason of ours — which is exactly what boot needs
        // for Layout and Switch Profile. The cost is that a
        // nil-action row is no longer disabled for free, so each
        // one says so.
        menu.autoenablesItems = false
        let profiles = profilesProvider()
        let phase = bootPhase

        // Problem zone (top): warning rows appear only when they
        // apply, so a healthy menu opens straight on Layout with
        // no permanent chrome above it. A missing permission
        // blocks everything, so it outranks a broken-config
        // issue. The fence separator is derived from presence —
        // "fence iff a warning exists" stays structural, so a
        // future third warning source can't forget it.
        var warnings: [NSMenuItem] = []
        if warning {
            // A loud row naming the *consequence* (not the jargon
            // "Accessibility"); click routes to the onboarding
            // grant step — the app's one "why + how" explainer —
            // not a bare System Settings link.
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
            // A determinate count, deliberately in words: menus
            // carry no progress bars, and the honest number is
            // apps LOOKED AT of apps running — `BootPhase` argues
            // why the attach tally would read as a stalled bar.
            // Disabled, monochrome, and gone the moment boot ends;
            // the rows it explains are greyed below.
            let status = NSMenuItem(
                title: Self.startingTitle(for: phase),
                action: nil,
                keyEquivalent: ""
            )
            status.isEnabled = false
            warnings.append(status)
            // Retitled in place while the menu stays open
            // (`setBootPhase`) — a menu opened at second 2 of a
            // ten-second boot would otherwise report second 2 for
            // as long as the user holds it.
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
            // A warning triangle makes the entry unmissable in
            // the quick menu; safe from the §3.7 status-glyph
            // distinction here because the row is text-labeled.
            issues.image = symbol("exclamationmark.triangle.fill")
            warnings.append(issues)
        }
        if !warnings.isEmpty {
            warnings.forEach(menu.addItem)
            menu.addItem(.separator())
        }

        // Daily actions — Layout first (the most-used control),
        // Switch Profile under it: same topic, no separator
        // between them. Switch Profile appears only when there is
        // something to switch *to* — a saved profile that isn't the
        // active one and isn't broken; with none, switching is a
        // no-op or impossible, so the row is pure noise.
        let hasSwitchTarget = profiles.all.contains {
            $0 != profiles.active
                && !profiles.broken.contains($0)
        }
        // A disabled context line naming the active profile — shown
        // only when a profile is loaded *and* a real alternative
        // exists to switch to (the same gate as the Switch Profile
        // row). With one profile or none there is no choice to
        // orient, so the name would be permanent chrome the
        // declutter (#324) removed. Any profile is loadable
        // regardless of screen count (#36), so this does not filter
        // by display setup.
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
        // Grey, don't hide (#171): both act on state the scan has
        // not finished collecting, and both will work in a
        // moment — which is the case dimming is for. The starting
        // row above is the sentence that says why.
        let layout = layoutItem()
        layout.isEnabled = !phase.isStarting
        menu.addItem(layout)
        if hasSwitchTarget {
            let switcher = switchProfileItem(profiles)
            switcher.isEnabled = !phase.isStarting
            menu.addItem(switcher)
        }

        // App chrome: Settings sits low, next to Quit, as in
        // every native menu-bar extra — not mid-list among the
        // workspace actions. "View Shortcuts…" shares Settings'
        // separator group and reads glance → editor (#326).
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

    // MARK: - Actions

    @objc private func openDashboard() {
        onOpenDashboard()
    }

    @objc private func showShortcuts(_ sender: NSMenuItem) {
        // AppKit needs a real key equivalent to render its native
        // trailing column, but Carbon already owns this shortcut
        // globally. Ignore AppKit's duplicate keyboard action;
        // mouse selection and programmatic dispatch still toggle.
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
