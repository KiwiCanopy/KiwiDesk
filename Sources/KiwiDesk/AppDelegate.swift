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
    /// The one update channel (#874), built with the delegate so
    /// no reader decides whether it starts, and handed to the
    /// status item and the dashboard alike (#1536,
    /// `UpdaterSeamGuardTests` pins both hand-overs).
    let updater: any AppUpdating = AppUpdaterFactory.make()

    var onboardingWindow: NSWindow?
    let onboardingModel = OnboardingModel()
    /// Boot's count for a relaunched "What's new" (#1667).
    let bootNarration = BootNarration()
    /// The slow-boot notice (#1715).
    let bootNotice = BootNoticeController()
    /// Cached dashboard controller to avoid constructing on refresh.
    private(set) var dashboardIfCreated: SettingsWindowController?
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
        created.setUpdater(updater)
        created.setStartTiling { [weak self] in self?.startTiling() }
        created.setCoreHold(coreHold)
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
    /// `wirePowerOffSheets`' observer (#2049).
    var powerOffObserver: NSObjectProtocol?
    /// Rebuilds the fixed-string main menu when the GUI language
    /// changes, so it honors the live-switch contract (#9) the
    /// rest of the app upholds.
    private var localeObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // First: the open event is current only while this runs.
        let origin = LaunchOrigin.of(
            NSAppleEventManager.shared().currentAppleEvent
        )

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
        statusItem.updater = updater
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
            self?.core.withUserMotion {
                _ = self?.core.execute(
                    "load_profile",
                    args: [.string(name)]
                )
            }
        }
        statusItem.layoutInfoProvider = { [weak self] in
            guard let self else { return LayoutMenuInfo.empty }
            return LayoutMenuInfo.current(from: self.core)
        }
        statusItem.onSetLayoutMode = { [weak self] mode, space in
            let args: [JSONValue] =
                space.map { [.string($0.raw), .string(mode.rawValue)] }
                ?? [.string(mode.rawValue)]
            self?.core.withUserMotion {
                _ = self?.core.execute("set_mode", args: args)
            }
            // Nothing to tell Settings: a quick-menu switch is
            // session-only, and since #1179 the draft narrates
            // the PROFILE rather than the session.
        }
        statusItem.onSaveLayoutToProfile = { [weak self] in
            self?.keepLayoutInProfile()
        }
        let shortcutsPanel = ShortcutsPanelController(
            core: core
        ) { [weak self] in
            self?.openSettingsFromTour(at: .shortcuts)
        }
        self.shortcutsPanel = shortcutsPanel
        statusItem.onShowShortcuts = { [weak shortcutsPanel] in
            shortcutsPanel?.toggle()
        }
        // Hotkey toggles the shortcuts reference panel (#330).
        core.uiBridge.onShowShortcuts = { [weak shortcutsPanel] in
            shortcutsPanel?.toggle()
        }
        // Every forceFront is an own front Core honors (#1861).
        NSApplication.ownFrontNote = { [weak core] number in
            core?.noteOwnFront(number: number)
        }
        // Opens or raises Settings without toggling (#678).
        core.uiBridge.onOpenSettings = { [weak self] in
            self?.dashboard.show()
        }
        // Reads bound open-combo live for quick menu.
        statusItem.shortcutsComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(
                core: self.core,
                lua: ShortcutsOpenBinding.lua
            )
        }
        statusItem.settingsComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(
                core: self.core,
                lua: KeybindingCatalog.openSettings.lua
            )
        }
        // Propagate boot readiness to status item and onboarding (#802).
        core.onBootPhaseChange = { [weak self] phase in
            self?.statusItem?.setBootPhase(phase)
            self?.onboardingModel.bootPhase = phase
            self?.bootNarration.phase = phase
            self?.bootNotice.phase(phase)
        }
        // Sparkle's relaunch is an in-place restart (#930).
        updater.onWillRelaunch = { [weak self] in
            self?.core.announceUpdateRelaunch()
        }
        statusItem.onShowConfigIssues = { [weak self] in
            self?.configIssues.show()
        }
        statusItem.onShowAccessibilityHelp = { [weak self] in
            self?.showAccessibilityHelp()
        }
        statusItem.onStartTiling = { [weak self] in
            self?.startTiling()
        }
        self.statusItem = statusItem
        wireBootNotice()

        // The error surface (#68 §3.7): the badge and the
        // standalone panel track the last config load.
        configIssues.model.onReload = { [weak self] in
            self?.core.withUserMotion { self?.core.loadConfig() }
        }
        // `delete_profile` clears the issue row and badge (#246).
        configIssues.model.onDeleteProfile = { [weak self] name in
            self?.core.withUserMotion {
                _ = self?.core.execute(
                    "delete_profile",
                    args: [.string(name)]
                )
            }
            // Keep an already-open dashboard's greyed row in sync (#246).
            self?.dashboardIfCreated?.refreshProfiles()
        }
        configIssues.model.onRevealProfile = revealProfile
        core.profiles.onCapturedLive = { [weak self] _, write in
            self?.dashboardIfCreated?.adoptKeptLayout(write)
        }
        core.onLiveProfileWritten = { [weak self] edit, persisted in
            self?.dashboardIfCreated?.adoptLiveWrite(
                edit,
                persisted: persisted
            )
        }
        core.onShortcutsDropped = { [weak self] spaces in
            self?.dashboardIfCreated?.adoptShortcutDrop(spaces)
        }
        wireBarMenus()
        wireWhatsNewTrail()
        core.onConfigIssuesChange = { [weak self] issues in
            self?.statusItem?.setConfigError(!issues.isEmpty)
            self?.configIssues.model.issues = issues
        }

        // Close a stale shortcuts panel on layer change (#603) —
        // read off the `layer_change` event like any other
        // consumer (#1168), so Core keeps one seam.
        core.bus.addSink { [weak self] event, _ in
            guard event == .layerChange else { return }
            self?.shortcutsPanel?.closeIfOpen()
        }
        // The menu bar's layer icon and, while the Space Bar is
        // off, the active Space (#1413) — off the bar's own
        // refresh, so every trigger the bar has reaches it.
        core.onStatusSpaceMarkChange = { [weak self] mark in
            self?.statusItem?.setSpaceMark(mark)
        }
        // Settings ▸ Spaces draws the Spaces the profile does not
        // hold (#1790), off the same refresh.
        core.onLiveOnlySpacesChange = { [weak self] spaces in
            self?.dashboardIfCreated?.showLiveOnlySpaces(spaces)
        }

        sigtermSource = QuitSignal.install()
        wirePowerOffSheets()

        permissions.onChange = { [weak self] trusted in
            self?.permissionChanged(trusted)
        }
        permissions.start()

        let trusted = permissions.isTrusted
        TilingConsent.seedAtLaunch(isTrusted: trusted)
        offerWhatsNew(origin: origin, trusted: trusted)
        syncCoreHold()
        if coreHold == .notStarted {
            // Granted, but Start Tiling never pressed (#2050).
            showOnboarding(at: .grant)
        } else if trusted {
            startManaging()
            if OnboardingDiscovery.shouldResume(
                isTrusted: trusted
            ) {
                showOnboarding(at: .keys)
            }
        } else {
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
}
