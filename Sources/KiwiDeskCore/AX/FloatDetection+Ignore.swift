import ApplicationServices
import Foundation

/// The ignore half of window classification: windows KiwiDesk
/// must never manage at all — no tracking, state entry, space
/// assignment, or events. Split from `FloatDetection.swift`
/// (file-size ceiling); the float-vs-tile half stays there.
extension FloatDetection {
    private static let ghosttyBundleID = "com.mitchellh.ghostty"

    /// Apps whose built-in ignore is layer-scoped: only their
    /// raised-layer panels are ignored, their layer-0 windows
    /// stay managed. Ghostty's quick terminal (#21); Raycast's
    /// command bar (#448) — listed as a belt for a dock-icon
    /// (regular-policy) Raycast, which the generic accessory +
    /// raised-layer rule below cannot see. Raycast 2 (the
    /// "Raycast X" beta) ships under its own bundle id.
    private static let layerScopedIgnoredApps: Set<String> = [
        ghosttyBundleID,
        "com.raycast.macos",
        "com.raycast-x.macos",
    ]

    /// Transient macOS UI processes whose windows are overlays,
    /// not user workspaces. Neither should enter state or receive
    /// a KiwiDesk focus border (#177).
    private static let ignoredSystemApps: Set<String> = [
        "com.apple.textinputmenuagent",
        "com.apple.textinputswitcher",
        // Menu-bar popovers (Wi-Fi, Bluetooth, sliders) are
        // accessory windows that would otherwise be tracked
        // and shown in the bars.
        "com.apple.controlcenter",
    ]

    public static func isBuiltInIgnoredApp(
        bundleID: String?
    ) -> Bool {
        guard let bundleID else { return false }
        return ignoredSystemApps.contains(bundleID.lowercased())
    }

    /// Windows KiwiDesk must not manage at all — no tracking,
    /// state entry, space assignment, or events. User rules are
    /// app-wide. Built-in layer-scoped rules ignore only an
    /// app's raised-layer panels (#21); `isAccessory` extends
    /// that to every third-party accessory-policy app (#448):
    /// a menu-bar app's raised-layer window is a Spotlight/
    /// Raycast-style command bar or HUD, and merely floating it
    /// still pins it to a space and drags it across space
    /// switches. Accessory apps' layer-0 windows (settings,
    /// pickers) stay managed floats.
    public static func shouldIgnore(
        bundleID: String?,
        layer: Int,
        isAccessory: Bool,
        rules: IgnoreRules
    ) -> Bool {
        rules.matches(bundleID: bundleID)
            || isBuiltInIgnoredApp(bundleID: bundleID)
            || layer != 0
                && (isAccessory
                    || bundleID.map {
                        layerScopedIgnoredApps
                            .contains($0.lowercased())
                    } == true)
    }

    /// Whether ignore classification for this app depends on
    /// CGWindow layers (the layer-scoped built-ins and every
    /// accessory app). User rules match the whole app and need
    /// no server scan.
    public static func requiresWindowLayers(
        bundleID: String?,
        isAccessory: Bool
    ) -> Bool {
        isAccessory
            || bundleID.map {
                layerScopedIgnoredApps.contains($0.lowercased())
            } == true
    }

    /// Window-id check for a built-in layer-scoped ignored
    /// panel. User-ignored apps do not use the panel-dismiss
    /// focus workaround: every window in those apps is ignored.
    public static func isBuiltInIgnoredPanel(
        bundleID: String?,
        id: WindowID,
        isAccessory: Bool
    ) -> Bool {
        guard
            requiresWindowLayers(
                bundleID: bundleID,
                isAccessory: isAccessory
            )
        else {
            return false
        }
        return shouldIgnore(
            bundleID: bundleID,
            layer: windowLayer(of: id) ?? 0,
            isAccessory: isAccessory,
            rules: IgnoreRules()
        )
    }

    /// CGWindow layers of all of an app's windows in ONE
    /// window-server round trip. Reconcile uses this instead
    /// of one lookup per window (AGENTS.md: never query the
    /// window server in a loop).
    public static func windowLayers(
        pid: pid_t
    ) -> [WindowID: Int] {
        let list =
            CGWindowListCopyWindowInfo(
                [.optionAll],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        var layers: [WindowID: Int] = [:]
        for info in list
        where info[kCGWindowOwnerPID as String] as? pid_t
            == pid
        {
            guard
                let number = info[kCGWindowNumber as String]
                    as? Int,
                let raw = UInt32(exactly: number)
            else { continue }
            layers[WindowID(raw)] =
                info[kCGWindowLayer as String] as? Int ?? 0
        }
        return layers
    }

    /// True while the app currently shows an ignored panel on
    /// screen. While Ghostty's quick terminal is open, AX
    /// reports the app's *main* window as focused — trusting
    /// that report would focus-follow to the main window's
    /// space even though the user is typing into the panel
    /// (issue #21). Known limit: visibility is a proxy for
    /// focus — with panel autohide disabled, a genuine main-
    /// window focus is also distrusted while the panel shows.
    /// Deliberate: suppressing a follow beats hijacking one.
    public static func hasVisibleIgnoredPanel(
        pid: pid_t,
        bundleID: String?,
        isAccessory: Bool
    ) -> Bool {
        // Cheap out before the window-list scan: only apps with
        // a layer-scoped built-in (or accessory policy, #448)
        // can show an ignored panel.
        guard
            requiresWindowLayers(
                bundleID: bundleID,
                isAccessory: isAccessory
            )
        else {
            return false
        }
        let list =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        return list.contains { info in
            info[kCGWindowOwnerPID as String] as? pid_t == pid
                && shouldIgnore(
                    bundleID: bundleID,
                    layer: info[kCGWindowLayer as String]
                        as? Int ?? 0,
                    isAccessory: isAccessory,
                    rules: IgnoreRules()
                )
        }
    }
}
