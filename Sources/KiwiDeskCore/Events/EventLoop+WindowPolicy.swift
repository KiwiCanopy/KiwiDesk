import AppKit
import ApplicationServices

/// Window/app classification shared by attachment, tracking, and
/// reconcile. Keeping it here prevents those funnels drifting.
extension EventLoop {
    nonisolated static func isOwnProcess(_ pid: pid_t) -> Bool {
        pid == getpid()
    }

    /// Accessory apps are observed once they expose a normal app
    /// window. This covers menu-bar apps such as Tailscale without
    /// attaching to every windowless agent at startup (#177).
    nonisolated static func shouldAttach(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        hasStandardWindow: Bool
    ) -> Bool {
        // Observe self before Settings exists, so its eventual
        // AXWindowCreated notification cannot depend on an app-
        // activation notification being delivered.
        if isOwnProcess(pid) { return true }
        return switch activationPolicy {
        case .regular:
            true
        case .accessory:
            hasStandardWindow
        case .prohibited:
            false
        @unknown default:
            false
        }
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
        layer: Int? = nil
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
        if ignoreRules.matches(bundleID: app.bundleID) {
            return true
        }
        guard let id = AXHelper.windowID(of: element) else {
            return false
        }
        return FloatDetection.shouldIgnore(
            bundleID: app.bundleID,
            layer: layer ?? FloatDetection.windowLayer(of: id) ?? 0,
            rules: ignoreRules
        )
    }
}
