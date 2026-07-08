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
    /// The saved profiles and the active one, pulled fresh
    /// each time the menu opens.
    var profilesProvider: () -> (active: String?, all: [String]) =
        { (nil, []) }

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
            button.image = NSImage(
                systemSymbolName:
                    "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "KiwiDesk (permission required)"
            )
            button.title = ""
            button.toolTip =
                "KiwiDesk needs Accessibility permission. "
                + "Window management is paused."
            return
        }
        if configError {
            button.image = NSImage(
                systemSymbolName:
                    "doc.badge.exclamationmark",
                accessibilityDescription:
                    "KiwiDesk (config issues)"
            )
            button.title = ""
            button.toolTip =
                "Parts of the configuration could not be "
                + "loaded — open Config Issues for details."
            return
        }
        button.toolTip = "KiwiDesk"
        if let modeIcon, !modeIcon.isEmpty {
            applyModeIcon(modeIcon, to: button)
        } else {
            button.title = ""
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "KiwiDesk"
            )
        }
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
        menu.addItem(switchProfileItem(profiles))
        menu.addItem(.separator())
        if configError {
            let issues = NSMenuItem(
                title: "Config Issues…",
                action: #selector(showConfigIssues),
                keyEquivalent: ""
            )
            issues.target = self
            issues.image = symbol("doc.badge.exclamationmark")
            menu.addItem(issues)
            menu.addItem(.separator())
        }
        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openDashboard),
            keyEquivalent: ","
        )
        settings.target = self
        settings.image = symbol("gearshape")
        menu.addItem(settings)

        let accessibility = NSMenuItem(
            title: "Accessibility Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        accessibility.target = self
        accessibility.image = symbol("accessibility")
        menu.addItem(accessibility)

        menu.addItem(.separator())
        let support = NSMenuItem(
            title: "Support KiwiDesk",
            action: #selector(openSupport),
            keyEquivalent: ""
        )
        support.target = self
        support.image = symbol("heart")
        menu.addItem(support)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit KiwiDesk",
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
            active.map { "KiwiDesk — \($0)" }
            ?? "KiwiDesk — no profile"
        let header = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        header.image = symbol("rectangle.3.group")
        return header
    }

    /// `load_profile` had no quick path before (§3.10): one
    /// submenu entry per saved profile, checkmark on the
    /// active one.
    private func switchProfileItem(
        _ profiles: (active: String?, all: [String])
    ) -> NSMenuItem {
        let parent = NSMenuItem(
            title: "Switch Profile",
            action: nil,
            keyEquivalent: ""
        )
        parent.image = symbol("square.stack.3d.up")
        let submenu = NSMenu()
        if profiles.all.isEmpty {
            let empty = NSMenuItem(
                title: "No saved profiles",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        for name in profiles.all {
            let entry = NSMenuItem(
                title: name,
                action: #selector(loadProfile(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.state =
                name == profiles.active ? .on : .off
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    private func symbol(_ name: String) -> NSImage? {
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
