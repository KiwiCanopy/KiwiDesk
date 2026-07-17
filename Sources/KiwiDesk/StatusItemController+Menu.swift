import AppKit
import KiwiDeskCore

/// The quick menu (#68 §3.10): rebuilt on every open so the
/// profile list and the conditional warning rows are always
/// current. The icon state machine lives in the main
/// `StatusItemController` file.
extension StatusItemController {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let profiles = profilesProvider()

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
        // between them.
        menu.addItem(layoutItem())
        menu.addItem(switchProfileItem(profiles))

        // App chrome: Settings sits low, next to Quit, as in
        // every native menu-bar extra — not mid-list among the
        // workspace actions. "View Shortcuts…" shares Settings'
        // separator group and reads glance → editor (#326).
        menu.addItem(.separator())
        let shortcuts = NSMenuItem(
            title: L("menu.view_shortcuts", "View Shortcuts…"),
            action: #selector(showShortcuts),
            keyEquivalent: ""
        )
        shortcuts.target = self
        shortcuts.image = symbol("keyboard")
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
        let quit = NSMenuItem(
            title: L("menu.quit", "Quit KiwiDesk"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.image = symbol("power")
        menu.addItem(quit)
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

    // MARK: - Actions

    @objc private func openDashboard() {
        onOpenDashboard()
    }

    @objc private func showShortcuts() {
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
