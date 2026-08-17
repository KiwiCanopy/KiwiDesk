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
    // These are `internal` (not `private`) so the onboarding-window
    // lifecycle can live in `AppDelegate+Onboarding.swift` (§2.1
    // file-size split); the class is `final` in a single executable
    // target, so this is module-internal, not real API surface.
    let core = KiwiCore()
    let permissions = PermissionMonitor()
    var statusItem: StatusItemController?
    var onboardingWindow: NSWindow?
    let onboardingModel = OnboardingModel()
    /// Created on first `dashboard` access. Kept alongside so
    /// the quick-menu closures can refresh an *already open*
    /// dashboard without constructing the whole settings stack
    /// on a mere layout switch.
    private var dashboardIfCreated: SettingsWindowController?
    var dashboard: SettingsWindowController {
        if let existing = dashboardIfCreated { return existing }
        let created = SettingsWindowController(core: core)
        // Seed the dashboard's permission banner from live state
        // and send its button straight to the macOS pane (#678
        // Phase 4 pass 9, turn 18). Deliberately NOT the quick
        // menu's route: that warning row opens the tour's grant
        // step, because someone clicking a menu-bar warning has
        // been told nothing yet. The banner has already said what
        // is wrong, one line above the button, to a reader who is
        // sitting in Settings — putting the tour between them and
        // the switch is a second explanation of what they just
        // read.
        created.setResolvePermission {
            PermissionMonitor.openSystemSettings()
        }
        // The SAME handler the Config Issues panel gets: Reveal
        // is one behaviour and both surfaces name the same file
        // (#246, architect review 2026-08-11).
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

        // Inject the persisted language pick before any view
        // reads `L(_:_:)` (issue #9). Read directly from
        // UserDefaults, NOT via `loadGuiConfig()` — a language
        // pick is a scalar app preference, not gui.json state,
        // and pulling a full live-state snapshot just to read
        // one value would be needless coupling (and `KiwiCore`
        // may not have started event tracking yet this early).
        // `nil` (absent key) means "System default".
        LocalizationManager.shared.adoptPersistedSelection(
            LocalizationPreference.read()
        )

        // The appearance pick (#678 item 8), read the same way
        // and for the same reasons: a scalar app preference, not
        // gui.json state. Applied to `NSApp` at launch so every
        // window the app opens later — Settings, the bars, the
        // border overlays — inherits it, rather than only the
        // one view that happens to carry a modifier.
        AppearancePreference.read().apply()

        // Install the application menu bar. A bare executable
        // ships none, so without this the auto-hide menu bar
        // never reveals while KiwiDesk is the active `.regular`
        // app (Settings focused) and text fields lack the
        // standard Edit shortcuts (#329). Rebuild it on a live
        // language change: its titles are fixed at build time,
        // so it must be reinstalled to re-localize (#9). `select`
        // reloads the catalog *after* republishing `selection`,
        // so hop to the main queue to read the new strings; the
        // initial value is dropped (the menu is built here).
        installMainMenu()
        localeObserver = LocalizationManager.shared.$selection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.installMainMenu() }

        let statusItem = StatusItemController()
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
            // `set_mode` already takes `[space,] mode`, so a
            // per-screen apply needs no new verb — the space is
            // simply named instead of defaulted.
            let args: [JSONValue] =
                space.map { [.string($0.raw), .string(mode.rawValue)] }
                ?? [.string(mode.rawValue)]
            _ = self?.core.execute("set_mode", args: args)
            // Drift-only refresh: a full `reload()` would
            // discard staged Settings edits mid-session.
            self?.dashboardIfCreated?.refreshLayoutDrift()
        }
        statusItem.onSaveLayoutToProfile = { [weak self] in
            guard let self,
                let name = self.core.profiles.currentName
            else { return }
            do {
                try self.core.persistProfile(named: name)
                self.dashboardIfCreated?.refreshLayoutDrift()
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
        // The bindable Lua open-hotkey (#330) toggles the same
        // panel — one close action for the key, the menu row, and
        // click-away, so the footer's "press it again to close"
        // hint holds.
        core.uiBridge.onShowShortcuts = { [weak shortcutsPanel] in
            shortcutsPanel?.toggle()
        }
        // The bindable "Open Settings" action (#678 item 18):
        // opens or raises, never toggles — a key that closed
        // Settings would discard draft state.
        core.uiBridge.onOpenSettings = { [weak self] in
            self?.dashboard.show()
        }
        // The quick-menu row shows the bound open-combo (if any),
        // read live from the resolved binding on each menu open.
        statusItem.shortcutsComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(core: self.core)
        }
        // Boot readiness (#802): ONE push, two consumers. The
        // status item stores it (icon rank, the menu's count row
        // and its greys), and the tour's grant step takes it
        // because it claims the windows are arranged and must not
        // say so mid-scan.
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
        // Delete routes through the same command as the GUI list;
        // `delete_profile` refreshes the issues, so the row (and
        // badge) clear themselves (#246).
        configIssues.model.onDeleteProfile = { [weak self] name in
            _ = self?.core.execute(
                "delete_profile",
                args: [.string(name)]
            )
            // Keep an already-open dashboard's greyed row in sync
            // (the command only refreshes the panel/badge) (#246).
            self?.dashboardIfCreated?.refreshProfiles()
        }
        configIssues.model.onRevealProfile = revealProfile
        core.onConfigIssuesChange = { [weak self] issues in
            self?.statusItem?.setConfigError(!issues.isEmpty)
            self?.configIssues.model.issues = issues
        }

        // Reflect the active keybinding mode on the menu bar
        // icon (custom modes carry their own indicator), and close
        // the shortcuts panel if it's open — its content is a
        // per-open snapshot of one mode, stale after a switch
        // (#603).
        core.keys.onLayerChange = { [weak self] mode in
            let icon =
                mode == KeybindingManager.defaultLayer
                ? nil
                : self?.core.keys.icon(for: mode)
            self?.statusItem?.setModeIcon(icon)
            self?.shortcutsPanel?.closeIfOpen()
        }

        // launchctl bootout (restart) delivers SIGTERM. AppKit
        // isn't guaranteed to translate it into
        // applicationWillTerminate for a LaunchAgent process, so
        // redirect it explicitly into AppKit's termination flow.
        // SIG_IGN prevents the default handler from killing the
        // process before the DispatchSource fires.
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
        // Keep an already-open dashboard's paused banner in sync
        // (the window survives close, so it may be up right now).
        dashboardIfCreated?.setPermissionPaused(!trusted)
        if trusted {
            statusItem?.setWarning(false)
            // Float the still-open wizard above the windows
            // `startManaging` is about to tile up, so the "granted →
            // Continue" screen (and the discovery pages after it)
            // can't sink behind them (#331).
            floatOnboardingAboveManagedWindows()
            startManaging()
        } else {
            // Revoked mid-session: pause management, warn. Reopen
            // straight at the grant step — the user already saw
            // the welcome, and the model may still rest on a prior
            // terminal step (e.g. a discovery page) that the
            // bare reuse path would otherwise redisplay.
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

    /// The quick menu has no footer to surface a save error in
    /// (the Settings path shows `profileWarning`), so a failed
    /// "Save Current Layout to Profile" — e.g. a screen-count
    /// mismatch — alerts instead of dying in the log.
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
