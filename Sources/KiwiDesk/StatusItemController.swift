import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the menu bar item: the status icon's state machine
/// (§3.7) — permission warning beats config error beats the
/// active mode's custom icon beats the standard glyph. The quick
/// menu (#68 §3.10) is built in `StatusItemController+Menu`.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate,
    NSPopoverDelegate
{
    var onOpenDashboard: () -> Void = {}
    /// Opens the read-only shortcuts reference panel (#326).
    var onShowShortcuts: () -> Void = {}
    var onShowConfigIssues: () -> Void = {}
    /// The combo bound to open the shortcuts panel (#330), rendered
    /// as native glyphs, or nil when unbound. Read fresh on each
    /// menu open so the "View Shortcuts…" row shows the live
    /// binding beside it (like `profilesProvider`).
    var shortcutsComboProvider: () -> String? = { nil }
    /// Opens the guided permission fix (the onboarding wizard at
    /// its grant step). Wired unconditionally; the *row* that
    /// invokes it appears only while Accessibility is missing.
    var onShowAccessibilityHelp: () -> Void = {}
    var onLoadProfile: (String) -> Void = { _ in }
    /// The saved profiles, the active one, and the unreadable
    /// ones, pulled fresh each menu open. Broken entries stay
    /// listed but disabled — greyed, not hidden; the remedy is
    /// the Config Issues panel, one entry up (#246, #171).
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
    /// `private(set)`: the menu builder in `+Menu` reads it to add
    /// the "Window Management Paused…" row, but only `setWarning`
    /// may mutate it — every write must go through `render()`.
    private(set) var warning = false
    /// The last config load left issues (§3.7) — a distinct
    /// badge so the two causes are never confused. `private(set)`
    /// for the same reason as `warning` (drives the Config Issues
    /// row; mutated only via `setConfigError`).
    private(set) var configError = false
    /// Active keybinding mode indicator (SF Symbol or emoji);
    /// nil restores the standard KiwiDesk icon.
    private var modeIcon: String?
    /// The one-time post-setup "look here" popover (#331), held
    /// while shown so the auto-dismiss and menu-open paths can
    /// close it.
    private var discoveryPopover: NSPopover?
    /// Cancellable auto-dismiss for the popover, so dismissing it
    /// early (menu open, outside click) drops the pending fire —
    /// the repo's cancellable-`Task` timer convention over a
    /// non-cancellable `asyncAfter`.
    private var discoveryDismiss: Task<Void, Never>?

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

    /// Shared SF Symbol → template-image helper for the menu
    /// builders (`+Menu`, `+Layout`) and `render`.
    func symbol(_ name: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        return image
    }

    // MARK: - Discovery popover (#331)

    /// Fires the one-time "look here" hint the instant onboarding
    /// closes. Anchored to the real status-item button — the only
    /// mechanism that maps to the icon's pixels (a centered window
    /// can't point at the menu bar). Non-modal `.transient`, so
    /// any outside click dismisses it; opening the quick menu (the
    /// success case) closes it via `menuNeedsUpdate`; a ~5s
    /// fallback covers the ignore case.
    ///
    /// Skipped when the icon is offscreen — an auto-hidden menu bar
    /// leaves the item with no on-screen pixels to point at, so a
    /// popover would land in a garbage corner. The wizard card's
    /// "you can get back from the menu bar" copy covers that user
    /// instead (#331).
    func showDiscoveryPopover() {
        guard let button = item.button,
            statusItemIsOnScreen(button)
        else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: LocaleScopedRoot {
                DiscoveryPopoverView()
            }
            .environmentObject(LocalizationManager.shared)
        )
        discoveryPopover = popover
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        discoveryDismiss = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.dismissDiscoveryPopover()
        }
    }

    /// Closes the discovery popover if it's still up. Shared by the
    /// menu-open success path and the timed fallback; safe to call
    /// when nothing is showing.
    func dismissDiscoveryPopover() {
        discoveryDismiss?.cancel()
        discoveryDismiss = nil
        discoveryPopover?.performClose(nil)
        discoveryPopover = nil
    }

    /// The `.transient` outside-click path closes the popover
    /// without routing through `dismissDiscoveryPopover`, so clear
    /// the retained reference and pending timer here too.
    func popoverDidClose(_ notification: Notification) {
        discoveryDismiss?.cancel()
        discoveryDismiss = nil
        discoveryPopover = nil
    }

    /// Whether the status-item button currently has on-screen
    /// pixels. A menu bar set to auto-hide (and not revealed)
    /// parks the item offscreen; anchoring there misplaces the
    /// popover, so callers skip it (#331).
    private func statusItemIsOnScreen(
        _ button: NSStatusBarButton
    ) -> Bool {
        guard let window = button.window else { return false }
        let frame = window.convertToScreen(button.frame)
        let mid = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.contains { $0.frame.contains(mid) }
    }
}
