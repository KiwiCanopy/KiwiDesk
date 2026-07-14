import AppKit
import KiwiDeskCore

/// Owns the menu bar item: the quick menu (#68 §3.10) and the
/// status icon's state machine (§3.7) — permission warning
/// beats config error beats the active mode's custom icon
/// beats the standard glyph.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onOpenSettings: () -> Void = {}
    var onOpenDashboard: () -> Void = {}
    var onShowConfigIssues: () -> Void = {}
    var onLoadProfile: (String) -> Void = { _ in }
    /// The saved profiles, the active one, and the unreadable
    /// ones, pulled fresh each time the menu opens. Broken
    /// entries stay listed but disabled — greyed, not hidden
    /// (#246, #171); the remedy lives in the Config Issues panel
    /// reachable from this same menu.
    var profilesProvider:
        () -> (
            active: String?, all: [String], broken: Set<String>
        ) = { (nil, [], []) }
    /// Provider for active layout mode and active profile status.
    var layoutInfoProvider:
        () -> (
            activeMode: LayoutMode?,
            activeProfileName: String?,
            savedModeForActiveSpace: LayoutMode?
        ) = { (nil, nil, nil) }
    var onSetLayoutMode: (LayoutMode) -> Void = { _ in }
    var onSaveLayoutToProfile: () -> Void = {}

    private let item: NSStatusItem
    private let menu = NSMenu()
    /// Missing-permission warning overrides everything.
    private var warning = false
    /// The last config load left issues (§3.7) — a distinct
    /// badge so the two causes are never confused.
    private var configError = false
    /// Active keybinding mode indicator (SF Symbol or emoji);
    /// nil restores the standard KiwiDesk icon.
    private var modeIcon: String?

    override init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        super.init()
        menu.delegate = self
        item.menu = menu
        render()
    }

    // MARK: - Icon states

    /// Toggles the missing-permission warning icon.
    func setWarning(_ warning: Bool) {
        self.warning = warning
        render()
    }

    /// Toggles the config-error badge (§3.7): shown when the
    /// last config load reported issues; permission warnings
    /// still win (without Accessibility nothing works
    /// regardless of config validity).
    func setConfigError(_ error: Bool) {
        configError = error
        render()
    }

    /// Reflects the active keybinding mode: a custom mode's
    /// icon replaces the standard menu bar glyph; the default
    /// mode (nil) restores it.
    func setModeIcon(_ icon: String?) {
        modeIcon = icon
        render()
    }

    private func render() {
        guard let button = item.button else { return }
        if warning {
            // Permission failure keeps the loud triangle; config
            // error uses a distinct, softer circle so the two are
            // never confused in the always-on glyph (§3.7).
            setStatusSymbol(
                "exclamationmark.triangle.fill",
                on: button,
                a11y: L(
                    "menu.status.warning.a11y",
                    "KiwiDesk (permission required)"
                ),
                tooltip: L(
                    "menu.status.warning.tooltip",
                    "KiwiDesk needs Accessibility permission. "
                        + "Window management is paused."
                )
            )
            return
        }
        if configError {
            setStatusSymbol(
                "exclamationmark.circle.fill",
                on: button,
                a11y: L(
                    "menu.status.config_error.a11y",
                    "KiwiDesk (config issues)"
                ),
                tooltip: L(
                    "menu.status.config_error.tooltip",
                    "Parts of the configuration could not be "
                        + "loaded — open Config Issues for details."
                )
            )
            return
        }
        button.toolTip = L("menu.status.tooltip", "KiwiDesk")
        if let modeIcon, !modeIcon.isEmpty {
            applyModeIcon(modeIcon, to: button)
        } else if let icon = BrandAssets.menuBarIcon
            ?? symbol("rectangle.3.group")
        {
            button.image = icon
            button.title = ""
        } else {
            // Last-ditch: never leave the slot blank.
            button.image = nil
            button.title = L("menu.status.a11y", "KiwiDesk")
        }
    }

    /// Sets the status button to the SF Symbol `name`, or — if
    /// that symbol doesn't resolve on this macOS version — a
    /// visible text fallback, so the menu bar item is never blank.
    /// A nil image with an empty title leaves an
    /// invisible-but-clickable slot that reads as a broken app
    /// (an invalid symbol name — `doc.badge.exclamationmark`,
    /// which does not exist — once did exactly that).
    private func setStatusSymbol(
        _ name: String,
        on button: NSStatusBarButton,
        a11y: String,
        tooltip: String
    ) {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: a11y
        )
        image?.isTemplate = true
        button.image = image
        button.title = image == nil ? "⚠︎" : ""
        button.toolTip = tooltip
    }

    /// A mode icon is either an SF Symbol name or a flat
    /// emoji; emoji fall back to the button title when no
    /// symbol matches.
    private func applyModeIcon(
        _ icon: String,
        to button: NSStatusBarButton
    ) {
        if let image = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: icon
        ) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = icon
        }
    }

    // MARK: - Quick menu (§3.10)

    /// Rebuilt on every open so the header, profile list, and
    /// the conditional Config Issues entry are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let profiles = profilesProvider()

        menu.addItem(headerItem(active: profiles.active))
        menu.addItem(.separator())
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

    func symbol(_ name: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        return image
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

    @objc private func openSupport() {
        NSWorkspace.shared.open(SupportLinks.koFi)
    }

    @objc private func loadProfile(_ sender: NSMenuItem) {
        onLoadProfile(sender.title)
    }
}
