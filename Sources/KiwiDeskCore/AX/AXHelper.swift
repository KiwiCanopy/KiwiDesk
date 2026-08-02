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

    // WindowServer-side queries (normalWindowCount,
    // pidsWithNormalWindows) live in
    // `AXHelper+WindowServer.swift`.

    /// Bounds every AX message this process sends. A message to
    /// an unresponsive app (stopped, deadlocked, paged out)
    /// blocks the caller for the system default of ~6 s per
    /// call; the boot scan makes several sequential main-thread
    /// calls per app, so one hung helper serializes startup
    /// into tens of seconds (#672 field report: ~60 s).
    /// Setting the timeout on the system-wide element makes it
    /// the process-wide default; an element carrying its own
    /// timeout keeps it. Deterministic repro for the failure
    /// this bounds: `kill -STOP` any GUI app, then boot.
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

    /// Whether a window is in native (green-button) fullscreen.
    /// Standard AX attribute string; the SDK header exposes no
    /// Swift constant for it. Snapshot at track/reconcile only —
    /// never in the border or layout path (AGENTS.md §5).
    public static func isFullscreen(
        _ element: AXUIElement
    ) -> Bool {
        attribute(
            element,
            "AXFullScreen",
            as: Bool.self
        ) ?? false
    }

    /// Current `AXEnhancedUserInterface` state of an app, read
    /// live (nil if the app does not answer). Used to bracket an
    /// instant frame-set: EUI-on apps animate programmatic frame
    /// changes themselves, so an un-animated placement must drop
    /// it for the set and restore whatever it was.
    public static func getEnhancedUserInterface(
        pid: pid_t
    ) -> Bool? {
        attribute(
            appElement(pid: pid),
            "AXEnhancedUserInterface",
            as: Bool.self
        )
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

    /// Chromium-family browsers (Chrome, Brave, Edge, Arc, …) build
    /// their AX tree lazily and gate it behind `AXManualAccessibility`
    /// rather than `AXEnhancedUserInterface` — until it is set,
    /// `kAXWindowsAttribute` stays empty and their windows are never
    /// discovered or tiled. Setting it makes that tree materialize.
    /// Harmless no-op on apps that do not recognize the attribute.
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

    /// Raises a window without focusing it or activating its
    /// app — z-order only. For a FOREIGN window this is blocking
    /// IPC (returns after the target app processed the action) and
    /// safe off the main thread; for an OWN-process window AppKit
    /// runs the ordering in-process on the calling thread, so the
    /// caller must gate on `mustRaiseOnMainThread` (#426).
    public static func raiseQuietly(_ element: AXUIElement) {
        AXUIElementPerformAction(
            element,
            kAXRaiseAction as CFString
        )
    }

    /// Whether `element`'s window belongs to our own process, so
    /// raising it must happen on the main thread:
    /// `AXUIElementPerformAction` on an own-process window runs
    /// AppKit's window ordering in-process on the calling thread,
    /// and the background z-order queue then trips AppKit's
    /// main-thread assertion (#426). A failed pid lookup is treated
    /// as own — the safe default, since a foreign window wrongly
    /// raised on the main thread only costs a blocking call, while
    /// an own window wrongly raised off it crashes.
    public static func mustRaiseOnMainThread(
        _ element: AXUIElement
    ) -> Bool {
        var pid: pid_t = 0
        let err = AXUIElementGetPid(element, &pid)
        return err != .success || pid == getpid()
    }

    /// Raises a window and gives it (and its app) focus.
    ///
    /// Order and options are load-bearing (#496): with several
    /// windows of one app across monitors, a COOPERATIVE
    /// `activate()` may be deferred by macOS and resolved
    /// against the app's most-recently-used window — key focus
    /// then lands on another display's sibling, not the raised
    /// target. So: make the target the app's MAIN window first,
    /// raise it (both synchronous AX round-trips — processed by
    /// the app before the next line runs), then FORCE the
    /// activation. The AeroSpace-proven sequence for the same
    /// macOS multi-monitor bug (their #101); public API only.
    ///
    /// **The deprecation warning on `.activateIgnoringOtherApps`
    /// is accepted deliberately — do NOT "clean it up".** Apple
    /// documents the flag as having no effect from macOS 14 on,
    /// and 14 is this app's deployment floor, so on paper it is
    /// dead code that only earns a warning. Observation says
    /// otherwise: an earlier build without it let focus jump to
    /// the MRU sibling — the very symptom described above.
    /// AeroSpace still ships the same flag today.
    ///
    /// Removing it needs evidence, not a doc string: an A/B on
    /// two displays, one app holding a window on each, 20+ focus
    /// commands per build, checking key focus lands on the
    /// targeted window and not the sibling. The failure is a
    /// race, so a handful of repetitions proves nothing — a
    /// probe of app-level activation proves less still, since
    /// this bug is about WHICH WINDOW inside an already-active
    /// app takes key focus.
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
