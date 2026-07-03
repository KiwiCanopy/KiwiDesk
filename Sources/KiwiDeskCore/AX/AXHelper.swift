import AppKit
import ApplicationServices

/// Private AX call that maps an `AXUIElement` to its `CGWindowID`.
/// Used by every serious macOS window manager; falls back cleanly
/// (returns an error code) if unavailable.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ out: UnsafeMutablePointer<UInt32>
) -> AXError

/// Thin, synchronous helpers around the public Accessibility API.
///
/// AX calls can block (Electron/WebKit apps answer lazily), so
/// callers must snapshot results instead of querying in loops.
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

    /// Whether a window is minimized to the Dock. Minimized
    /// windows stay in the AX window list but must not occupy
    /// layout slots.
    public static func isMinimized(
        _ element: AXUIElement
    ) -> Bool {
        attribute(
            element,
            kAXMinimizedAttribute,
            as: Bool.self
        ) ?? false
    }

    /// Keeps Electron/WebKit AX trees warm to avoid 100-300 ms
    /// query latency. See AGENTS.md guardrails before changing.
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

    /// Raises a window without focusing it or activating its
    /// app — z-order only. Cross-app ordering is best-effort:
    /// without private window-server APIs, AX can only order
    /// a window within its own app's layer.
    @MainActor
    public static func raiseQuietly(_ element: AXUIElement) {
        AXUIElementPerformAction(
            element,
            kAXRaiseAction as CFString
        )
    }

    /// Raises a window and gives it (and its app) focus.
    @MainActor
    public static func raise(
        _ element: AXUIElement,
        pid: pid_t
    ) {
        AXUIElementPerformAction(
            element,
            kAXRaiseAction as CFString
        )
        AXUIElementSetAttributeValue(
            element,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        NSRunningApplication(processIdentifier: pid)?
            .activate()
    }

    /// Builds a `ManagedWindow` snapshot from an AX element.
    public static func snapshot(
        element: AXUIElement,
        pid: pid_t,
        appName: String
    ) -> ManagedWindow? {
        guard let id = windowID(of: element) else { return nil }
        return ManagedWindow(
            id: id,
            pid: pid,
            appName: appName,
            title: title(of: element),
            frame: frame(of: element)
        )
    }
}
