import AppKit
import KiwiDeskCore

/// Status bar quick menu builder (#68 §3.10, #802).
extension StatusItemController {
    func menuWillOpen(_ menu: NSMenu) {
        onMenuOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        onMenuClose()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        let phase = bootPhase

        var warnings: [NSMenuItem] = []
        // Never beside the paused row: no grant, no start (#2050).
        if tilingIdle, !warning {
            let start = NSMenuItem(
                title: L("common.start_tiling", "Start Tiling"),
                action: #selector(startTiling),
                keyEquivalent: ""
            )
            start.target = self
            start.image = symbol("play.fill")
            start.isEnabled = true
            warnings.append(start)
        }
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

        // KiwiHub's View side switches the layout, the profile and
        // KiwiVision (#2309 ruling 8). Enabled while KiwiDesk boots
        // or waits for Start Tiling: the side greys its own chips.
        let hub = NSMenuItem(
            title: L(
                "menu.open_kiwihub",
                "Open %1$@…",
                L("kiwihub.name", "KiwiHub")
            ),
            action: #selector(openKiwiHub(_:)),
            keyEquivalent: ""
        )
        hub.target = self
        hub.image = symbol("square.grid.2x2")
        hub.isEnabled = true
        // The status menu is not the app's MainMenu, so its key
        // equivalent is active only while this menu is tracking.
        // Using the native column gives the combo AppKit's dimmed,
        // right-aligned treatment; its duplicate keyboard action
        // is ignored in `openKiwiHub` below.
        if let combo = kiwiHubComboProvider() {
            combo.applyMenuEquivalent(
                to: hub,
                layoutChar: LayoutKeyGlyph.char
            )
        }
        menu.addItem(hub)
        let settings = NSMenuItem(
            title: L("menu.settings", "Settings…"),
            action: #selector(openDashboard),
            keyEquivalent: ","
        )
        settings.target = self
        settings.image = symbol("gearshape")
        // The live global chord where one is bound (#1381); the
        // `⌘,` above is the app menu's, which fires only while a
        // KiwiDesk window is key.
        if let combo = settingsComboProvider() {
            combo.applyMenuEquivalent(
                to: settings,
                layoutChar: LayoutKeyGlyph.char
            )
        }
        menu.addItem(settings)

        menu.addItem(.separator())
        if let whatsNew = makeWhatsNewItem() {
            menu.addItem(whatsNew)
        }
        if let updates = makeUpdatesItem() {
            menu.addItem(updates)
        }
        let quit = NSMenuItem(
            title: L("menu.quit", "Quit KiwiDesk"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.image = symbol("power")
        menu.addItem(quit)
    }

    /// The count row's title, built on menu open and retitled per
    /// chunk while the menu is up: the boot count's one sentence
    /// (`BootCountText`, #2874), empty once boot is past the scan.
    static func startingTitle(for phase: BootPhase) -> String {
        BootCountText.line(for: phase) ?? ""
    }

    @objc private func openDashboard() {
        // Carbon owns a bound chord globally; AppKit's duplicate
        // keyDown is dropped — but `⌘,` has no Carbon twin, so its
        // keyDown is the row's only path (#1381).
        if menuActionIsKeyDown(), settingsComboProvider() != nil {
            return
        }
        onOpenDashboard()
    }

    @objc private func openKiwiHub(_ sender: NSMenuItem) {
        // Carbon owns shortcut globally; ignore AppKit's duplicate keyDown
        // event.
        if menuActionIsKeyDown() { return }
        onOpenKiwiHub()
    }

    @objc private func showConfigIssues() {
        onShowConfigIssues()
    }

    @objc private func startTiling() {
        onStartTiling()
    }

    @objc private func showAccessibilityHelp() {
        onShowAccessibilityHelp()
    }

}
