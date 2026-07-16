import AppKit
import KiwiDeskCore
import SwiftUI
@preconcurrency import UserNotifications

/// Entry point: permissions, menu bar, and windows. All window
/// management logic lives in `KiwiCore`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate,
    NSWindowDelegate
{
    private let core = KiwiCore()
    private let permissions = PermissionMonitor()
    private var statusItem: StatusItemController?
    private var onboardingWindow: NSWindow?
    private let onboardingModel = OnboardingModel()
    /// Created on first `dashboard` access. Kept alongside so
    /// the quick-menu closures can refresh an *already open*
    /// dashboard without constructing the whole settings stack
    /// on a mere layout switch.
    private var dashboardIfCreated: SettingsWindowController?
    private var dashboard: SettingsWindowController {
        if let existing = dashboardIfCreated { return existing }
        let created = SettingsWindowController(core: core)
        dashboardIfCreated = created
        return created
    }
    private let configIssues = ConfigIssuesWindowController()
    /// Held strongly so the source stays active for the
    /// lifetime of the process.
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        let statusItem = StatusItemController()
        statusItem.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        statusItem.onOpenDashboard = { [weak self] in
            self?.dashboard.show()
        }
        // The quick menu's dynamic entries (#68 §3.10).
        statusItem.profilesProvider = { [weak self] in
            (
                active: self?.core.profiles.currentName,
                all: self?.core.profiles.list() ?? [],
                broken: Set(
                    self?.core.profiles.brokenNames() ?? []
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
            guard let self else { return (nil, nil, nil) }
            return (
                self.core.activeSpace?.mode,
                self.core.profiles.currentName,
                self.core.savedModeForActiveSpace()
            )
        }
        statusItem.onSetLayoutMode = { [weak self] mode in
            _ = self?.core.execute(
                "set_mode",
                args: [.string(mode.rawValue)]
            )
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
        statusItem.onShowConfigIssues = { [weak self] in
            self?.configIssues.show()
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
        configIssues.model.onRevealProfile = { [weak self] name in
            guard
                let url = try? self?.core.profiles.fileURL(
                    name: name
                )
            else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        core.onConfigIssuesChange = { [weak self] issues in
            self?.statusItem?.setConfigError(!issues.isEmpty)
            self?.configIssues.model.issues = issues
        }

        // Reflect the active keybinding mode on the menu bar
        // icon (custom modes carry their own indicator).
        core.keys.onModeChange = { [weak self] mode in
            let icon =
                mode == KeybindingManager.defaultMode
                ? nil
                : self?.core.keys.icon(for: mode)
            self?.statusItem?.setModeIcon(icon)
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

        if permissions.isTrusted {
            startManaging()
        } else {
            statusItem.setWarning(true)
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        core.stop()
        permissions.stop()
    }

    // MARK: - Permission transitions

    private func permissionChanged(_ trusted: Bool) {
        onboardingModel.isTrusted = trusted
        if trusted {
            statusItem?.setWarning(false)
            startManaging()
        } else {
            // Revoked mid-session: pause management, warn.
            core.stop()
            statusItem?.setWarning(true)
            notifyPermissionLost()
            showOnboarding()
        }
    }

    private func startManaging() {
        statusItem?.setWarning(false)
        core.start()
    }

    // MARK: - Onboarding window

    private func showOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        onboardingModel.isTrusted = permissions.isTrusted
        onboardingModel.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        onboardingModel.onOpenSpaceSettings = {
            DisplaySpacesSetting.openSystemSettings()
        }
        onboardingModel.displayCount = { [weak self] in
            self?.core.state.workspaces.allDisplays.count ?? 1
        }
        onboardingModel.onFinish = { [weak self] in
            self?.closeOnboarding()
        }

        let view = OnboardingView(model: onboardingModel)
            .environmentObject(LocalizationManager.shared)
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.title = L("onboarding.window.title", "KiwiDesk Setup")
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        onboardingWindow = window

        NSApp.activateAsRegular()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func closeOnboarding() {
        // Closing routes through `windowWillClose`, which does
        // the demote + teardown (also covers the red-button
        // close, which the "finish" button used to bypass).
        onboardingWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let closing = notification.object as? NSWindow,
            closing === onboardingWindow
        else { return }
        onboardingWindow = nil
        // Demote only if no other content window remains (the
        // still-visible closing window is excluded).
        NSApp.deactivateIfNoWindows(excluding: closing)
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

    // MARK: - Notifications

    /// Posts a system notification about revoked permission.
    /// `UNUserNotificationCenter` requires a real app bundle, so
    /// bare SwiftPM executables fall back to logging only.
    private func notifyPermissionLost() {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog(
                "KiwiDesk: Accessibility permission revoked; "
                    + "window management paused."
            )
            return
        }
        // Resolved on the main actor before the completion
        // handler, which runs on an arbitrary queue and can't
        // call the main-actor-isolated `L()`.
        let title = L(
            "notification.permission_lost.title",
            "KiwiDesk stopped managing windows"
        )
        let body = L(
            "notification.permission_lost.body",
            "Accessibility permission was revoked. "
                + "Re-enable it in System Settings > "
                + "Privacy & Security > Accessibility."
        )
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.alert]
        ) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: "kiwidesk.permission-lost",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
