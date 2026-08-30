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

    /// Bounds process-wide AX messaging timeout to avoid hangs (#672).
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

    /// Unminimizes a window from the Dock (#673).
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

    /// True if window is in native fullscreen.
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

    /// Sets `AXEnhancedUserInterface` on application element.
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

    /// Sets `AXManualAccessibility` for Chromium-family browsers.
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

    /// True if window belongs to own process and must raise on main thread
    /// (#426).
    public static func mustRaiseOnMainThread(
        _ element: AXUIElement
    ) -> Bool {
        var pid: pid_t = 0
        let err = AXUIElementGetPid(element, &pid)
        return err != .success || pid == getpid()
    }

    /// Raises window and activates its app with MRU disambiguation (#496).
    /// `.activateIgnoringOtherApps` accepted deliberately on macOS 14+.
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
