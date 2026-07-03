import AppKit
import KiwiDeskCore
import SwiftUI
@preconcurrency import UserNotifications

/// Entry point: permissions, menu bar, and windows. All window
/// management logic lives in `KiwiCore`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let core = KiwiCore()
    private let permissions = PermissionMonitor()
    private var statusItem: StatusItemController?
    private var onboardingWindow: NSWindow?
    private let onboardingModel = OnboardingModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = StatusItemController()
        statusItem.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        self.statusItem = statusItem

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
        window.center()
        onboardingWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
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
