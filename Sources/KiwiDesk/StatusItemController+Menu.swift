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
            Self.applyMenuEquivalent(combo, to: hub)
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
            Self.applyMenuEquivalent(combo, to: settings)
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

    static func applyMenuEquivalent(
        _ combo: KeyCombo,
        to item: NSMenuItem
    ) {
        // A menu key equivalent has no side, so drawing `R⌘H` as
        // `⌘H` would promise the left key too (#2601).
        guard !combo.modifiers.isSided else { return }
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
