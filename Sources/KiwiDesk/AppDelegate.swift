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
    private lazy var dashboard = SettingsWindowController(
        core: core
    )
    private let configIssues = ConfigIssuesWindowController()
    /// Held strongly so the source stays active for the
    /// lifetime of the process.
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                all: self?.core.profiles.list() ?? []
            )
        }
        statusItem.onLoadProfile = { [weak self] name in
            _ = self?.core.execute(
                "load_profile",
                args: [.string(name)]
            )
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
            Self.openDesktopAndDockSettings()
        }
        onboardingModel.onFinish = { [weak self] in
            self?.closeOnboarding()
        }

        let view = OnboardingView(model: onboardingModel)
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.title = "KiwiDesk Setup"
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

    /// Opens System Settings › Desktop & Dock, where "Displays
    /// have separate Spaces" lives (#8). Falls back to the
    /// Settings root if the pane identifier is ever renamed.
    private static func openDesktopAndDockSettings() {
        let pane =
            "x-apple.systempreferences:"
            + "com.apple.Desktop-Settings.extension"
        let target =
            URL(string: pane)
            ?? URL(string: "x-apple.systempreferences:")
        guard let target else { return }
        NSWorkspace.shared.open(target)
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
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.alert]
        ) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "KiwiDesk stopped managing windows"
            content.body =
                "Accessibility permission was revoked. "
                + "Re-enable it in System Settings > Privacy "
                + "& Security > Accessibility."
            let request = UNNotificationRequest(
                identifier: "kiwidesk.permission-lost",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
