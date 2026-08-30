import AppKit
import KiwiDeskCore
import SwiftUI

/// Manages menu bar status item, icon state transitions, and menu coordination
/// (#68, #802).
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onOpenDashboard: () -> Void = {}
    var onShowShortcuts: () -> Void = {}
    var onShowConfigIssues: () -> Void = {}
    var shortcutsComboProvider: () -> KeyCombo? = { nil }

    var updater: any AppUpdating = NoUpdater()
    var onShowAccessibilityHelp: () -> Void = {}
    var onLoadProfile: (String) -> Void = { _ in }
    var profilesProvider:
        () -> (
            active: String?, all: [String], broken: Set<String>
        ) = { (nil, [], []) }
    var layoutInfoProvider: () -> LayoutMenuInfo = {
        LayoutMenuInfo.empty
    }
    var onSetLayoutMode: (LayoutMode, SpaceID?) -> Void = { _, _ in
    }
    var onSaveLayoutToProfile: () -> Void = {}

    private let item: StatusItemHandle
    private let menu = NSMenu()
    private(set) var warning = false
    private(set) var configError = false
    private var modeIcon: String?
    private(set) var bootPhase: BootPhase = .ready
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
