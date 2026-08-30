import AppKit
import KiwiDeskCore
import SwiftUI

/// Manages menu bar status item, icon state transitions, and menu coordination
/// (#68, #802).
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onOpenDashboard: () -> Void = {}
    /// Opens the read-only shortcuts reference panel (#326).
    var onShowShortcuts: () -> Void = {}
    var onShowConfigIssues: () -> Void = {}
    /// The combo bound to open the shortcuts panel (#330), read
    /// fresh on each menu open so AppKit renders the live binding.
    var shortcutsComboProvider: () -> KeyCombo? = { nil }

    /// Drives "Check for Updates…" (#874). Inert by default —
    /// `AppUpdater.swift` owns why.
    var updater: any AppUpdating = NoUpdater()
    var onShowAccessibilityHelp: () -> Void = {}
    var onLoadProfile: (String) -> Void = { _ in }
    /// Saved profiles, pulled fresh each menu open; broken entries
    /// stay listed but disabled — greyed, not hidden (#246, #171).
    var profilesProvider:
        () -> (
            active: String?, all: [String], broken: Set<String>
        ) = { (nil, [], []) }
    /// What the Layout submenu draws from, fresh per open (#752).
    var layoutInfoProvider: () -> LayoutMenuInfo = {
        LayoutMenuInfo.empty
    }
    var onSetLayoutMode: (LayoutMode, SpaceID?) -> Void = { _, _ in
    }
    var onSaveLayoutToProfile: () -> Void = {}

    /// Injected menu-bar slot so tests never register a real
    /// system item (`StatusItemHandle`, the #565-class seam).
    private let item: StatusItemHandle
    private let menu = NSMenu()
    /// `private(set)`: only `setWarning` may mutate — every write
    /// goes through `render()`.
    private(set) var warning = false
    /// Distinct badge so the two causes never blur (§3.7); mutated
    /// only via `setConfigError`, the same rule as `warning`.
    private(set) var configError = false
    private var modeIcon: String?
    /// ONE stored value (#802), read by the icon AND the menu
    /// builder — two reads of one fact showed half the signal
    /// (architect review, 2026-08-12).
    private(set) var bootPhase: BootPhase = .ready
    /// Held so a phase published mid-tracking can retitle the open
    /// menu's row in place (owner, on device, 2026-08-12).
    weak var startingRow: NSMenuItem?

    init(item: (any StatusItemHandle)? = nil) {
        self.item = item ?? SystemStatusItem()
        super.init()
        menu.delegate = self
        self.item.menu = menu
        render()
    }

    /// Sets missing-permission warning icon state.
    func setWarning(_ warning: Bool) {
        self.warning = warning
        render()
    }

    /// Sets config-error badge state (§3.7).
    func setConfigError(_ error: Bool) {
        configError = error
        render()
    }

    /// Updates boot readiness phase and re-renders if transition crossed
    /// (#802).
    func setBootPhase(_ phase: BootPhase) {
        let wasStarting = bootPhase.isStarting
        bootPhase = phase
        if let startingRow, case .scanning = phase {
            startingRow.title = Self.startingTitle(for: phase)
        }
        guard phase.isStarting != wasStarting else { return }
        render()
    }

    /// Whether startup initialization is in progress (#802).
    var starting: Bool { bootPhase.isStarting }

    /// Sets custom icon for active keybinding mode.
    func setModeIcon(_ icon: String?) {
        modeIcon = icon
        render()
    }

    /// Menu bar button anchor for coach marks (#678).
    var anchorButton: NSStatusBarButton? { item.button }

    private func render() {
        guard let button = item.button else { return }
        button.appearsDisabled = starting
        if warning {
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
        if starting {
            button.toolTip = L(
                "menu.status.starting.tooltip",
                "KiwiDesk is starting up — going through your "
                    + "open apps."
            )
            applyBrandIcon(
                to: button,
                a11y: L(
                    "menu.status.starting.a11y",
                    "KiwiDesk (starting up)"
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
                        + "loaded — open %1$@ for details.",
                    L("config_issues.title", "Config Issues")
                )
            )
            return
        }
        button.toolTip = L("menu.status.tooltip", "KiwiDesk")
        if let modeIcon, !modeIcon.isEmpty {
            applyModeIcon(modeIcon, to: button)
        } else {
            applyBrandIcon(
                to: button,
                a11y: L("menu.status.a11y", "KiwiDesk")
            )
        }
    }

    func symbol(_ name: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        return image
    }
}

/// Live system NSStatusItem wrapper (`StatusItemSeamGuardTests`).
@MainActor
private final class SystemStatusItem: StatusItemHandle {
    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
    }

    var button: NSStatusBarButton? { item.button }

    var menu: NSMenu? {
        get { item.menu }
        set { item.menu = newValue }
    }
}
