import AppKit
import ApplicationServices

/// Central listener for system events.
///
/// Watches app launches/terminations via `NSWorkspace`, attaches
/// an `AXApplicationObserver` per app, and translates raw AX
/// notifications into typed `KiwiEvent`s. It keeps no layout
/// state itself — consumers apply events to the state managers.
@MainActor
public final class EventLoop {
    public var onEvent: @MainActor (KiwiEvent) -> Void = { _ in }

    private var observers: [pid_t: AXApplicationObserver] = [:]
    private var elements: [pid_t: [WindowID: AXUIElement]] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var screenToken: NSObjectProtocol?
    public private(set) var isRunning = false

    public init() {}

    // MARK: - Lifecycle

    /// Starts observing. Requires Accessibility permission.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        registerWorkspaceObservers()
        for app in NSWorkspace.shared.runningApplications {
            attach(app: app)
        }
        publishDisplays()
    }

    /// Stops observing and forgets all tracked windows.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens {
            center.removeObserver(token)
        }
        workspaceTokens = []
        if let screenToken {
            NotificationCenter.default
                .removeObserver(screenToken)
        }
        screenToken = nil
        for observer in observers.values {
            observer.invalidate()
        }
        observers = [:]
        elements = [:]
    }

    // MARK: - App tracking

    private func registerWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let launch = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Queue .main delivers on the main thread, but the
            // closure is nonisolated and Notification is not
            // Sendable; bridge manually.
            nonisolated(unsafe) let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appLaunched(app)
            }
        }
        let term = center.addObserver(
            forName:
                NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            nonisolated(unsafe) let app = note.runningApplication
            MainActor.assumeIsolated {
                guard let app else { return }
                self?.appTerminated(app)
            }
        }
        workspaceTokens = [launch, term]

        screenToken = NotificationCenter.default.addObserver(
            forName:
                NSApplication
                .didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.publishDisplays()
            }
        }
    }

    private func appLaunched(_ app: NSRunningApplication) {
        attach(app: app)
        onEvent(
            .appLaunched(
                pid: app.processIdentifier,
                name: app.localizedName ?? "?"
            )
        )
    }

    private func appTerminated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        observers[pid]?.invalidate()
        observers[pid] = nil
        for id in elements[pid, default: [:]].keys {
            onEvent(.windowDestroyed(id))
        }
        elements[pid] = nil
        onEvent(.appTerminated(pid: pid))
    }

    /// Attaches AX observation to a regular (Dock-visible) app.
    private func attach(app: NSRunningApplication) {
        guard app.activationPolicy == .regular else { return }
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        guard let observer = AXApplicationObserver(pid: pid)
        else { return }

        let name = app.localizedName ?? "?"
        observer.onNotification = { [weak self] note, element in
            self?.handle(note, element, pid: pid, appName: name)
        }
        observers[pid] = observer
        // Keep Electron/WebKit AX trees warm (see AGENTS.md).
        AXHelper.setEnhancedUserInterface(pid: pid, enabled: true)

        for element in AXHelper.windows(pid: pid) {
            track(element, pid: pid, appName: name)
        }
    }

    // MARK: - Window tracking

    private func track(
        _ element: AXUIElement,
        pid: pid_t,
        appName: String
    ) {
        guard AXHelper.role(of: element) == kAXWindowRole,
            let window = AXHelper.snapshot(
                element: element,
                pid: pid,
                appName: appName
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        elements[pid, default: [:]][window.id] = element
        observers[pid]?.observe(window: element)
        onEvent(.windowCreated(window))
    }

    private func windowID(
        of element: AXUIElement,
        pid: pid_t
    ) -> WindowID? {
        if let id = AXHelper.windowID(of: element) {
            return id
        }
        // Destroyed elements no longer answer queries; fall back
        // to comparing against tracked elements.
        return elements[pid, default: [:]]
            .first { CFEqual($1, element) }?.key
    }

    private func handle(
        _ note: String,
        _ element: AXUIElement,
        pid: pid_t,
        appName: String
    ) {
        switch note {
        case kAXWindowCreatedNotification:
            track(element, pid: pid, appName: appName)
        case kAXUIElementDestroyedNotification:
            guard let id = windowID(of: element, pid: pid),
                elements[pid]?[id] != nil
            else { return }
            elements[pid]?[id] = nil
            onEvent(.windowDestroyed(id))
        case kAXFocusedWindowChangedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(.windowFocused(id))
        case kAXWindowMovedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowMoved(
                    id,
                    AXHelper.frame(of: element)
                )
            )
        case kAXWindowResizedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowResized(
                    id,
                    AXHelper.frame(of: element)
                )
            )
        case kAXTitleChangedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowTitleChanged(
                    id,
                    AXHelper.title(of: element)
                )
            )
        default:
            break
        }
    }

    // MARK: - Displays

    private func publishDisplays() {
        let displays = NSScreen.screens.compactMap { screen in
            screen.kiwiDisplay
        }
        onEvent(.displaysChanged(displays))
    }
}

extension Notification {
    /// The `NSRunningApplication` attached to an `NSWorkspace`
    /// launch/termination notification.
    fileprivate var runningApplication: NSRunningApplication? {
        userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
    }
}

extension NSScreen {
    /// Converts an `NSScreen` into a KiwiDesk display snapshot.
    var kiwiDisplay: Display? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber
        else { return nil }
        return Display(
            id: DisplayID(number.uint32Value),
            name: localizedName,
            frame: frame,
            visibleFrame: visibleFrame
        )
    }
}
