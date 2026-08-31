import AppKit
import ApplicationServices

/// Private AX call that maps an `AXUIElement` to its `CGWindowID`.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ out: UnsafeMutablePointer<UInt32>
) -> AXError

/// Synchronous helpers around the public Accessibility API.
public enum AXHelper {
    /// Whether the process has Accessibility permission.
    public static func isTrusted(prompt: Bool = false) -> Bool {
        guard prompt else { return AXIsProcessTrusted() }
        // Literal value of kAXTrustedCheckOptionPrompt; the SDK
        // global is not concurrency-safe under Swift 6.
        let key = "AXTrustedCheckOptionPrompt"
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// The AX element representing an application.
    public static func appElement(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    /// Stable window ID for an AX window element.
    public static func windowID(
        of element: AXUIElement
    ) -> WindowID? {
        var raw: UInt32 = 0
        guard _AXUIElementGetWindow(element, &raw) == .success,
            raw != 0
        else { return nil }
        return WindowID(raw)
    }

    /// Generic attribute getter.
    public static func attribute<T>(
        _ element: AXUIElement,
        _ name: String,
        as type: T.Type
    ) -> T? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            element,
            name as CFString,
            &value
        )
        guard err == .success else { return nil }
        return value as? T
    }

    /// All window elements of an application.
    public static func windows(
        pid: pid_t
    ) -> [AXUIElement] {
        let app = appElement(pid: pid)
        let list = attribute(
            app,
            kAXWindowsAttribute,
            as: [AXUIElement].self
        )
        return list ?? []
    }

    /// Bounds process-wide AX messaging timeout (#672): set on the
    /// system-wide element it becomes the process default; an
    /// element carrying its own timeout keeps it. Deterministic
    /// repro for the hang this bounds: `kill -STOP` any GUI app,
    /// then boot.
    public static func setGlobalMessagingTimeout(
        seconds: Float
    ) {
        AXUIElementSetMessagingTimeout(
            AXUIElementCreateSystemWide(),
            seconds
        )
    }

    /// The window that currently has focus within an app.
    public static func focusedWindow(
        pid: pid_t
    ) -> AXUIElement? {
        attribute(
            appElement(pid: pid),
            kAXFocusedWindowAttribute,
            as: AXUIElement.self
        )
    }

    public static func title(of element: AXUIElement) -> String {
        attribute(element, kAXTitleAttribute, as: String.self)
            ?? ""
    }

    public static func frame(of element: AXUIElement) -> CGRect {
        var rect = CGRect.zero
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            element,
            "AXFrame" as CFString,
            &value
        )
        guard err == .success,
            let axValue = value,
            CFGetTypeID(axValue) == AXValueGetTypeID()
        else { return rect }
        // Sound: type verified via CFGetTypeID above.
        let frameValue = unsafeDowncast(
            axValue,
            to: AXValue.self
        )
        AXValueGetValue(frameValue, .cgRect, &rect)
        return rect
    }

    public static func role(of element: AXUIElement) -> String {
        attribute(element, kAXRoleAttribute, as: String.self)
            ?? ""
    }

    public static func subrole(of element: AXUIElement) -> String {
        attribute(element, kAXSubroleAttribute, as: String.self)
            ?? ""
    }

    /// True if window is minimized to the Dock.
    public static func isMinimized(
        _ element: AXUIElement
    ) -> Bool {
        attribute(
            element,
            kAXMinimizedAttribute,
            as: Bool.self
        ) ?? false
    }

    /// Unminimizes a window from the Dock (#673). Activating an
    /// app does NOT deminiaturize, so this is the only way to make
    /// an all-minimized app show something.
    @discardableResult
    public static func unminimize(
        _ element: AXUIElement
    ) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            kCFBooleanFalse
        ) == .success
    }

    /// True if window is in native fullscreen. Snapshot at
    /// track/reconcile only — never in the border or layout path
    /// (AGENTS.md §5).
    public static func isFullscreen(
        _ element: AXUIElement
    ) -> Bool {
        attribute(
            element,
            "AXFullScreen",
            as: Bool.self
        ) ?? false
    }

    /// Reads `AXEnhancedUserInterface` state.
    public static func getEnhancedUserInterface(
        pid: pid_t
    ) -> Bool? {
        attribute(
            appElement(pid: pid),
            "AXEnhancedUserInterface",
            as: Bool.self
        )
    }

    /// Sets `AXEnhancedUserInterface` — keeps Electron/WebKit AX
    /// trees warm. See accessibility.md before changing.
    public static func setEnhancedUserInterface(
        pid: pid_t,
        enabled: Bool
    ) {
        let app = appElement(pid: pid)
        AXUIElementSetAttributeValue(
            app,
            "AXEnhancedUserInterface" as CFString,
            enabled as CFBoolean
        )
    }

    /// Sets `AXManualAccessibility` for Chromium-family browsers:
    /// until set, `kAXWindowsAttribute` stays empty and their
    /// windows are never discovered or tiled. Harmless no-op on
    /// apps that do not recognize it.
    public static func setManualAccessibility(
        pid: pid_t,
        enabled: Bool
    ) {
        AXUIElementSetAttributeValue(
            appElement(pid: pid),
            "AXManualAccessibility" as CFString,
            enabled as CFBoolean
        )
    }

    /// Raises window without activating app (z-order only, verify via
    /// `ZOrderDrain`, #426, #684).
    public static func raiseQuietly(_ element: AXUIElement) {
        AXUIElementPerformAction(
            element,
            kAXRaiseAction as CFString
        )
    }

    /// True if window belongs to own process and must raise on the
    /// main thread (#426). A failed pid lookup is treated as own —
    /// the safe default: a foreign window wrongly raised on main
    /// costs a blocking call, an own window wrongly raised off it
    /// crashes.
    public static func mustRaiseOnMainThread(
        _ element: AXUIElement
    ) -> Bool {
        var pid: pid_t = 0
        let err = AXUIElementGetPid(element, &pid)
        return err != .success || pid == getpid()
    }

    /// Raises window and activates its app (#496). The order is
    /// load-bearing: make the target the app's MAIN window first,
    /// raise it (both synchronous), THEN force the activation — or
    /// macOS resolves a deferred activate against the MRU sibling
    /// on another display. `.activateIgnoringOtherApps` is accepted
    /// deliberately on macOS 14+ — do NOT "clean it up": removing
    /// it needs a 20+-command two-display A/B, not a doc string.
    /// The AeroSpace-proven sequence for the same bug (their
    /// #101); public API only.
    @MainActor
    public static func raise(
        _ element: AXUIElement,
        pid: pid_t
    ) {
        AXUIElementSetAttributeValue(
            element,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        AXUIElementPerformAction(
            element,
            kAXRaiseAction as CFString
        )
        NSRunningApplication(processIdentifier: pid)?
            .activate(options: .activateIgnoringOtherApps)
    }

    /// Builds a `ManagedWindow` snapshot from an AX element.
    public static func snapshot(
        element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) -> ManagedWindow? {
        guard let id = windowID(of: element) else { return nil }
        return ManagedWindow(
            id: id,
            pid: pid,
            appName: app.name,
            appBundleID: app.bundleID,
            title: title(of: element),
            frame: frame(of: element)
        )
    }
}
