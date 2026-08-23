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
    ///
    /// Own windows discriminate per WINDOW, never per process
    /// (#678 item 18): a window marked with
    /// `OwnWindowTiling.identifier` tiles like any other, and
    /// every other own window is chrome and stays force-floated.
    /// That type's doc carries the argument and the census of
    /// which own window is which — do not re-list them here.
    nonisolated static func shouldForceFloat(
        pid: pid_t,
        activationPolicy: NSApplication.ActivationPolicy,
        tilesAsOwnWindow: Bool
    ) -> Bool {
        if isOwnProcess(pid) { return !tilesAsOwnWindow }
        return floatsAsAccessory(activationPolicy)
    }

    /// The third-party clause, named once and shared by the two
    /// predicates that need it. `shouldForceFloat` and
    /// `classifiesAsOverlay` answer disjoint domains — own
    /// windows vs everyone else — so neither is expressible as
    /// the other with an argument pinned, and pinning one was
    /// how a parameter came to be passed into a branch that
    /// could not reach it.
    nonisolated static func floatsAsAccessory(
        _ activationPolicy: NSApplication.ActivationPolicy
    ) -> Bool {
        activationPolicy == .accessory
    }

    /// The live force-float verdict for one tracked window. The
    /// own-window arm reads the tiling mark through
    /// `ownWindowIdentifier`, which is the injected seam — so a
    /// test proves BOTH arms without a real `NSWindow`, and a
    /// call site that stops consulting it reds
    /// (`SelfWindowExclusionTests`, the flag being otherwise
    /// unobservable from outside).
    func shouldForceFloat(pid: pid_t, id: WindowID) -> Bool {
        Self.shouldForceFloat(
            pid: pid,
            activationPolicy: NSRunningApplication(
                processIdentifier: pid
            )?.activationPolicy ?? .prohibited,
            tilesAsOwnWindow: Self.isOwnProcess(pid)
                && ownWindowIdentifier(id)
                    == OwnWindowTiling.identifier
        )
    }

    /// Maps an own window id to its `NSWindow` — the one place
    /// AX identity meets AppKit identity, shared by the ignore
    /// gate (`canBecomeMain`) and by `ownWindowIdentifier`'s
    /// production default (the tiling mark).
    static func ownWindow(number: Int) -> NSWindow? {
        NSApplication.shared.windows.first { $0.windowNumber == number }
    }

    /// The *structural* half of the transient-overlay
    /// classification (#300): third-party accessory-app windows
    /// — but never our own (#315). Any own window that reaches
    /// tracking is main-capable by construction
    /// (`shouldIgnoreOwnWindow` dropped every own panel — ghost,
    /// drop zone, border ring — before classification), so the
    /// own-process half of `shouldForceFloat` must not sweep an
    /// own window into the launcher class: a marked own window
    /// tiles outright (#678 item 18) and force-floated own
    /// chrome keeps its focus ring. Third-party accessory apps
    /// stay swept — their windows are menu-bar utility UI, the
    /// #300 case.
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
            && floatsAsAccessory(activationPolicy)
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
    /// window. Its internal overlay panels cannot, giving one
    /// robust distinction for drag/drop, App Bar, and border
    /// overlays. Titled dialogs and alerts (e.g. Sparkle update
    /// alerts) that can become key are managed as floating chrome;
    /// borderless utility panels and hidden windows stay ignored.
    nonisolated static func shouldIgnoreOwnWindow(
        pid: pid_t,
        canBecomeMain: Bool,
        canBecomeKey: Bool = false,
        isTitled: Bool = false,
        isVisible: Bool = true
    ) -> Bool {
        guard isOwnProcess(pid) else { return false }
        guard isVisible else { return true }
        let isManaged = canBecomeMain || (canBecomeKey && isTitled)
        return !isManaged
    }

    func shouldIgnore(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        layer: Int? = nil,
        isAccessory: Bool
    ) -> Bool {
        if Self.isOwnProcess(pid) {
            guard
                let window = AXHelper.windowID(of: element)
                    .flatMap({ Self.ownWindow(number: Int($0.raw)) })
            else {
                return true
            }
            return Self.shouldIgnoreOwnWindow(
                pid: pid,
                canBecomeMain: window.canBecomeMain,
                canBecomeKey: window.canBecomeKey,
                isTitled: window.styleMask.contains(.titled),
                isVisible: window.isVisible
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
