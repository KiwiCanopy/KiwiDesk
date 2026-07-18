import AppKit
import KiwiDeskCore

/// The quick menu (#68 §3.10): rebuilt on every open so the
/// profile list and the conditional warning rows are always
/// current. The icon state machine lives in the main
/// `StatusItemController` file.
extension StatusItemController {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Opening the quick menu IS the discovery popover's success
        // case — the user found the icon. Close it so the hint and
        // the menu never overlap (#331).
        dismissDiscoveryPopover()
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
            let current = NSMenuItem(
                title: L(
                    "menu.active_profile",
                    "Profile: %1$@",
                    active
                ),
                action: nil,
                keyEquivalent: ""
            )
            current.isEnabled = false
            menu.addItem(current)
        }
        menu.addItem(layoutItem())
        if hasSwitchTarget {
            menu.addItem(switchProfileItem(profiles))
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
            action: #selector(showShortcuts),
            keyEquivalent: ""
        )
        shortcuts.target = self
        shortcuts.image = symbol("keyboard")
        // Show the bound open-combo beside the row (#330) — drawn
        // via attributedTitle, NEVER keyEquivalent (that would be a
        // live second trigger, and a mirrored MainMenu item would
        // fire it globally while frontmost). Nothing shown unbound.
        if let combo = shortcutsComboProvider() {
            shortcuts.attributedTitle = Self.menuRowTitle(
                shortcutsTitle,
                trailing: combo
            )
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

    /// A menu title with a dimmed, right-aligned trailing hint —
    /// the bound open-combo beside "View Shortcuts…" (#330). A
    /// right tab stop pushes the combo toward the row's trailing
    /// edge, matching how a native `⌘,` key equivalent sits.
    private static func menuRowTitle(
        _ title: String,
        trailing: String
    ) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        // Right tab positions the combo so its right edge sits at
        // `location`. Derive it from the rendered title + combo
        // widths (plus a gap) so a long localized title can't run
        // into the combo; floor at 200pt so short titles still
        // align consistently.
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let titleWidth = (title as NSString)
            .size(withAttributes: attrs).width
        let comboWidth = (trailing as NSString)
            .size(withAttributes: attrs).width
        let location = max(200, ceil(titleWidth + 16 + comboWidth))
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: location)
        ]
        let result = NSMutableAttributedString(
            string: title,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        result.append(
            NSAttributedString(
                string: "\t" + trailing,
                attributes: [
                    .font: font,
                    .paragraphStyle: paragraph,
                    .foregroundColor:
                        NSColor.secondaryLabelColor,
                ]
            )
        )
        return result
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
