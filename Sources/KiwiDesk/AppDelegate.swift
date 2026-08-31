import AppKit
import Combine
import KiwiDeskCore
import SwiftUI

/// Entry point: permissions, menu bar, and windows. All window
/// management logic lives in `KiwiCore`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate,
    NSWindowDelegate
{
    // Internal for `AppDelegate+Onboarding.swift` file split (§2.1).
    let core = KiwiCore()
    let permissions = PermissionMonitor()
    var statusItem: StatusItemController?

    var onboardingWindow: NSWindow?
    let onboardingModel = OnboardingModel()
    /// Cached dashboard controller to avoid constructing on refresh.
    private var dashboardIfCreated: SettingsWindowController?
    var dashboard: SettingsWindowController {
        if let existing = dashboardIfCreated { return existing }
        let created = SettingsWindowController(core: core)
        // Opens System Settings pane directly from banner (#678).
        created.setResolvePermission {
            PermissionMonitor.openSystemSettings()
        }
        // Shared profile reveal handler (#246).
        created.setRevealProfile(revealProfile)
        created.setShowTour { [weak self] in
            self?.replayOnboardingTour()
        }
        created.setPermissionPaused(!permissions.isTrusted)
        dashboardIfCreated = created
        return created
    }
    private let configIssues = ConfigIssuesWindowController()
    /// The read-only shortcuts reference panel (#326), retained so
    /// it survives close/reopen. Its "Edit in Settings…" bridge
    /// opens the dashboard already navigated to Shortcuts.
    var shortcutsPanel: ShortcutsPanelController?
    /// Held strongly so the source stays active for the
    /// lifetime of the process.
    private var sigtermSource: DispatchSourceSignal?
    /// Rebuilds the fixed-string main menu when the GUI language
    /// changes, so it honors the live-switch contract (#9) the
    /// rest of the app upholds.
    private var localeObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Shorten the hover-help delay before any window opens
        // (`ToolTipDelay` carries why).
        ToolTipDelay.install()

        // Adopt persisted language before views read L(_:_:) (#9).
        LocalizationManager.shared.adoptPersistedSelection(
            LocalizationPreference.read()
        )

        // Apply appearance preference to NSApp at launch (#678).
        AppearancePreference.read().apply()

        // Install menu bar for standard Edit shortcuts (#329) and rebuild
        // on language change (#9).
        installMainMenu()
        localeObserver = LocalizationManager.shared.$selection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }

        let statusItem = StatusItemController()
        // Single construction of updater (#874, UpdaterSeamGuardTests).
        statusItem.updater = AppUpdaterFactory.make()
        statusItem.onOpenDashboard = { [weak self] in
            self?.dashboard.show()
        }
        // The quick menu's dynamic entries (#68 §3.10).
        statusItem.profilesProvider = { [weak self] in
            (
                active: self?.core.profiles.currentName,
                all: self?.core.profiles.list() ?? [],
                broken: Set(
                    self?.core.profiles.brokenProfiles()
                        .map(\.name) ?? []
                )
            )
        }
        statusItem.onLoadProfile = { [weak self] name in
            _ = self?.core.execute(
                "load_profile",
                args: [.string(name)]
            )
        }
        statusItem.layoutInfoProvider = { [weak self] in
            guard let self else { return LayoutMenuInfo.empty }
            return LayoutMenuInfo.current(from: self.core)
        }
        statusItem.onSetLayoutMode = { [weak self] mode, space in
            let args: [JSONValue] =
                space.map { [.string($0.raw), .string(mode.rawValue)] }
                ?? [.string(mode.rawValue)]
            _ = self?.core.execute("set_mode", args: args)
            // Nothing to tell Settings: a quick-menu switch is
            // session-only, and since #1179 the draft narrates
            // the PROFILE rather than the session.
        }
        statusItem.onSaveLayoutToProfile = { [weak self] in
            guard let self,
                let name = self.core.profiles.currentName
            else { return }
            do {
                // Capture-live (#1179); the draft's baseline
                // follows through `onProfileCapturedLive`, which
                // the `save_profile` command reaches too.
                try self.core.persistProfile(
                    named: name,
                    modes: nil
                )
            } catch {
                self.core.onLog("profile save failed: \(error)")
                self.presentLayoutSaveFailure(error)
            }
        }
        let shortcutsPanel = ShortcutsPanelController(
            core: core
        ) { [weak self] in
            self?.openShortcutsSettings()
        }
        self.shortcutsPanel = shortcutsPanel
        statusItem.onShowShortcuts = { [weak shortcutsPanel] in
            shortcutsPanel?.toggle()
        }
        // Hotkey toggles the shortcuts reference panel (#330).
        core.uiBridge.onShowShortcuts = { [weak shortcutsPanel] in
            shortcutsPanel?.toggle()
        }
        // Opens or raises Settings without toggling (#678).
        core.uiBridge.onOpenSettings = { [weak self] in
            self?.dashboard.show()
        }
        // Reads bound open-combo live for quick menu.
        statusItem.shortcutsComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(core: self.core)
        }
        // Propagate boot readiness to status item and onboarding (#802).
        core.onBootPhaseChange = { [weak self] phase in
            self?.statusItem?.setBootPhase(phase)
            self?.onboardingModel.bootPhase = phase
        }
        statusItem.onShowConfigIssues = { [weak self] in
            self?.configIssues.show()
        }
        statusItem.onShowAccessibilityHelp = { [weak self] in
            self?.showAccessibilityHelp()
        }
        self.statusItem = statusItem

        // The error surface (#68 §3.7): the badge and the
        // standalone panel track the last config load.
        configIssues.model.onReload = { [weak self] in
            self?.core.loadConfig()
        }
        // `delete_profile` clears the issue row and badge (#246).
        configIssues.model.onDeleteProfile = { [weak self] name in
            _ = self?.core.execute(
                "delete_profile",
                args: [.string(name)]
            )
            // Keep an already-open dashboard's greyed row in sync (#246).
            self?.dashboardIfCreated?.refreshProfiles()
        }
        configIssues.model.onRevealProfile = revealProfile
        core.onProfileCapturedLive = { [weak self] _ in
            self?.dashboardIfCreated?.adoptKeptLayout()
        }
        core.onConfigIssuesChange = { [weak self] issues in
            self?.statusItem?.setConfigError(!issues.isEmpty)
            self?.configIssues.model.issues = issues
        }

        // Update menu bar icon and close stale shortcuts panel on
        // layer change (#603).
        core.keys.onLayerChange = { [weak self] mode in
            let icon =
                mode == KeybindingManager.defaultLayer
                ? nil
                : self?.core.keys.icon(for: mode)
            self?.statusItem?.setModeIcon(icon)
            self?.shortcutsPanel?.closeIfOpen()
        }

        // Redirect SIGTERM from launchctl into AppKit termination flow.
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(
            signal: SIGTERM,
            queue: .main
        )
        src.setEventHandler { NSApp.terminate(nil) }
        src.resume()
        sigtermSource = src

        permissions.onChange = { [weak self] trusted in
            self?.permissionChanged(trusted)
        }
        permissions.start()

        let trusted = permissions.isTrusted
        if trusted {
            startManaging()
            if OnboardingDiscovery.shouldResume(
                isTrusted: trusted
            ) {
                showOnboarding(at: .keys)
            }
        } else {
            statusItem.setWarning(true)
            showOnboarding(at: .grant)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        core.stop()
        permissions.stop()
    }

    /// The App menu's "Settings…" item (⌘,) — opens the
    /// dashboard just like the quick menu's entry.
    @objc private func openDashboardFromMenu(_ sender: Any?) {
        dashboard.show()
    }

    private func installMainMenu() {
        NSApp.mainMenu = MainMenu.make(
            settingsTarget: self,
            settingsAction: #selector(openDashboardFromMenu)
        )
    }

    // MARK: - Permission transitions

    private func permissionChanged(_ trusted: Bool) {
        onboardingModel.isTrusted = trusted
        // Keep an already-open dashboard's paused banner in sync.
        dashboardIfCreated?.setPermissionPaused(!trusted)
        if trusted {
            statusItem?.setWarning(false)
            // Float wizard above windows being tiled (#331).
            floatOnboardingAboveManagedWindows()
            startManaging()
        } else {
            // Revoked mid-session: pause management and reopen at grant step.
            core.stop()
            statusItem?.setWarning(true)
            notifyPermissionLost()
            showOnboarding(at: .grant)
        }
    }

    private func startManaging() {
        statusItem?.setWarning(false)
        core.start()
    }

    /// Alerts on layout save failure from quick menu.
    private func presentLayoutSaveFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "menu.layout.save_failed.title",
            "Couldn't Save Layout"
        )
        alert.informativeText = L(
            "profiles.save_failed",
            "Saving failed: %1$@",
            "\(error)"
        )
        NSApp.activate()
        alert.runModal()
    }
}
