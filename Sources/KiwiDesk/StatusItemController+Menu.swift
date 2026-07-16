import AppKit
import KiwiDeskCore

/// The quick menu (#68 §3.10): rebuilt on every open so the
/// header, the profile list, and the conditional warning rows
/// are always current. The icon state machine lives in the main
/// `StatusItemController` file.
extension StatusItemController {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let profiles = profilesProvider()

        menu.addItem(headerItem(active: profiles.active))
        menu.addItem(.separator())
        if warning {
            // Without Accessibility nothing tiles, so the fix
            // outranks every daily action: a loud row naming the
            // *consequence* (not the jargon "Accessibility"),
            // right under the header, above Layout. Click routes
            // to the onboarding grant step — the app's one "why +
            // how" explainer — not a bare System Settings link.
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
            menu.addItem(paused)
            menu.addItem(.separator())
        }
        menu.addItem(layoutItem())
        menu.addItem(.separator())
        menu.addItem(switchProfileItem(profiles))
        menu.addItem(.separator())
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
            menu.addItem(issues)
            menu.addItem(.separator())
        }
        let settings = NSMenuItem(
            title: L("menu.settings", "Settings…"),
            action: #selector(openDashboard),
            keyEquivalent: ","
        )
        settings.target = self
        settings.image = symbol("gearshape")
        menu.addItem(settings)

        let accessibility = NSMenuItem(
            title: L(
                "menu.accessibility_settings",
                "Accessibility Settings…"
            ),
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        accessibility.target = self
        accessibility.image = symbol("accessibility")
        menu.addItem(accessibility)

        menu.addItem(.separator())
        let support = NSMenuItem(
            title: L("menu.support", "Support KiwiDesk"),
            action: #selector(openSupport),
            keyEquivalent: ""
        )
        support.target = self
        support.image = symbol("heart")
        menu.addItem(support)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: L("menu.quit", "Quit KiwiDesk"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.image = symbol("power")
        menu.addItem(quit)
    }

    /// The disabled header row: branding slot + which profile
    /// is live right now (§3.8/§3.10).
    private func headerItem(active: String?) -> NSMenuItem {
        let title =
            active.map {
                L("menu.header.active", "KiwiDesk — %1$@", $0)
            }
            ?? L(
                "menu.header.no_profile",
                "KiwiDesk — no profile"
            )
        let header = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        header.image =
            BrandAssets.menuBarIcon
            ?? symbol("rectangle.3.group")
        return header
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

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openDashboard() {
        onOpenDashboard()
    }

    @objc private func showConfigIssues() {
        onShowConfigIssues()
    }

    @objc private func showAccessibilityHelp() {
        onShowAccessibilityHelp()
    }

    @objc private func openSupport() {
        NSWorkspace.shared.open(SupportLinks.koFi)
    }

    @objc private func loadProfile(_ sender: NSMenuItem) {
        onLoadProfile(sender.title)
    }
}
