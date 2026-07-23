import AppKit
import ApplicationServices

/// Window/app classification shared by attachment, tracking, and
/// reconcile. Keeping it here prevents those funnels drifting.
extension EventLoop {
    nonisolated static func isOwnProcess(_ pid: pid_t) -> Bool {
        pid == getpid()
    }

    /// Regular and accessory apps are observed from launch.
    /// Accessory observation must begin while the app is still
    /// windowless: its first standard window may appear without a
    /// later activation notification (#177).
    nonisolated static func shouldAttach(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        isIgnored: Bool
    ) -> Bool {
        guard !isIgnored else { return false }
        // Observe self before Settings exists, so its eventual
        // AXWindowCreated notification cannot depend on an app-
        // activation notification being delivered.
        if isOwnProcess(pid) { return true }
        return switch activationPolicy {
        case .regular, .accessory:
            true
        case .prohibited:
            false
        @unknown default:
            false
        }
    }

    /// Complete ownership gate for an already-delivered callback or
    /// reconcile. Requiring the observer prevents a callback queued
    /// before detach from recreating state; re-reading policy closes
    /// the interval before the next workspace lifecycle notification.
    nonisolated static func ownsObservation(
        hasObserver: Bool,
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        isIgnored: Bool
    ) -> Bool {
        hasObserver
            && shouldAttach(
                pid: pid,
                activationPolicy: activationPolicy,
                isIgnored: isIgnored
            )
    }

    /// Standard windows from accessory/menu-bar apps are real
    /// managed windows, but float by default: their utility UI
    /// should never be absorbed into a desktop layout.
    nonisolated static func shouldForceFloat(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy
    ) -> Bool {
        isOwnProcess(pid) || activationPolicy == .accessory
    }

    func shouldForceFloat(pid: pid_t) -> Bool {
        Self.shouldForceFloat(
            pid: pid,
            activationPolicy: NSRunningApplication(
                processIdentifier: pid
            )?.activationPolicy ?? .prohibited
        )
    }

    /// The *structural* half of the transient-overlay
    /// classification (#300): third-party accessory-app windows
    /// — but never our own (#315). Any own window that reaches
    /// tracking is main-capable by construction
    /// (`shouldIgnoreOwnWindow` dropped every own panel — ghost,
    /// drop zone, border ring — before classification), so the
    /// own-process half of `shouldForceFloat` must not sweep the
    /// Settings window into the launcher class: it still floats
    /// by default, it just keeps its focus ring. Third-party
    /// accessory apps stay swept — their windows are menu-bar
    /// utility UI, the #300 case.
    ///
    /// Load-bearing since #448: the hard ignore gate
    /// (`FloatDetection.shouldIgnore`'s `isAccessory` arm) also
    /// keys on this predicate. It must stay exactly
    /// "third-party accessory activation policy" — widening it
    /// toward the fuller transient-overlay definition (panel
    /// subroles, raised layers) would silently widen the ignore
    /// gate to regular apps' panels, which must only float.
    nonisolated static func classifiesAsOverlay(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy
    ) -> Bool {
        !isOwnProcess(pid)
            && shouldForceFloat(
                pid: pid,
                activationPolicy: activationPolicy
            )
    }

    func classifiesAsOverlay(pid: pid_t) -> Bool {
        Self.classifiesAsOverlay(
            pid: pid,
            activationPolicy: NSRunningApplication(
                processIdentifier: pid
            )?.activationPolicy ?? .prohibited
        )
    }

    /// App-wide hard gate shared by attachment, queued AX
    /// callbacks, and reconcile. Built-in system overlays use
    /// the same no-observer path as user `ignore_rules`.
    func shouldIgnoreApp(bundleID: String?) -> Bool {
        ignoreRules.matches(bundleID: bundleID)
            || FloatDetection.isBuiltInIgnoredApp(
                bundleID: bundleID
            )
    }

    /// KiwiDesk's normal Settings window can become a main app
    /// window. Its NSPanels cannot, giving one robust distinction
    /// for drag/drop, App Bar, and border overlays regardless of
    /// the AX subrole AppKit reports for each panel.
    nonisolated static func shouldIgnoreOwnWindow(
        pid: pid_t,
        canBecomeMain: Bool
    ) -> Bool {
        isOwnProcess(pid) && !canBecomeMain
    }

    func shouldIgnore(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        layer: Int? = nil,
        isAccessory: Bool
    ) -> Bool {
        if Self.isOwnProcess(pid) {
            let canBecomeMain =
                AXHelper.windowID(of: element)
                .flatMap { id in
                    NSApp.windows.first {
                        $0.windowNumber == Int(id.raw)
                    }
                }?.canBecomeMain ?? false
            return Self.shouldIgnoreOwnWindow(
                pid: pid,
                canBecomeMain: canBecomeMain
            )
        }
        if shouldIgnoreApp(bundleID: app.bundleID) {
            return true
        }
        guard let id = AXHelper.windowID(of: element) else {
            return false
        }
        return FloatDetection.shouldIgnore(
            bundleID: app.bundleID,
            layer: layer ?? FloatDetection.windowLayer(of: id) ?? 0,
            isAccessory: isAccessory,
            rules: ignoreRules
        )
    }
}
