import AppKit
import KiwiDeskCore
import SwiftUI
@preconcurrency import UserNotifications

/// Entry point: wires permissions, event loop, and menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let eventLoop = EventLoop()
    private var state = StateCoordinator()
    private let permissions = PermissionMonitor()
    private let sleepWake = SleepWakeManager()
    private let tiler = TilingEngine()
    private var statusItem: StatusItemController?
    private var onboardingWindow: NSWindow?
    private let onboardingModel = OnboardingModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = StatusItemController()
        statusItem.onOpenSettings = {
            PermissionMonitor.openSystemSettings()
        }
        self.statusItem = statusItem

        tiler.elementProvider = { [weak self] id in
            self?.eventLoop.element(for: id)
        }
        eventLoop.onEvent = { [weak self] event in
            guard let self else { return }
            self.state.apply(event)
            if case .displaysChanged = event {
                self.tiler.displaysChanged()
            }
            if TilingEngine.shouldRetile(after: event) {
                self.tiler.retile(state: self.state)
            }
        }

        sleepWake.captureState = { [weak self] in
            self?.state.snapshot()
        }
        sleepWake.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        sleepWake.start()

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
        eventLoop.stop()
        permissions.stop()
        sleepWake.stop()
    }

    /// Re-applies window frames after wake/unlock.
    private func restore(_ snapshot: StateSnapshot) {
        for record in snapshot.windows {
            guard
                let element = eventLoop.element(
                    for: record.windowID
                )
            else { continue }
            WindowControl.setFrame(record.frame, of: element)
        }
    }

    // MARK: - Permission transitions

    private func permissionChanged(_ trusted: Bool) {
        onboardingModel.isTrusted = trusted
        if trusted {
            statusItem?.setWarning(false)
            startManaging()
        } else {
            // Revoked mid-session: pause management, warn.
            eventLoop.stop()
            statusItem?.setWarning(true)
            notifyPermissionLost()
            showOnboarding()
        }
    }

    private func startManaging() {
        statusItem?.setWarning(false)
        eventLoop.start()
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
