import ApplicationServices
import Foundation

/// Window ignore classification and layer-scoped panel detection
/// (`FloatDetection.swift`).
extension FloatDetection {
    private static let ghosttyBundleID = "com.mitchellh.ghostty"

    /// Layer-scoped ignored apps: only raised-layer panels are ignored
    /// (#21, #448).
    private static let layerScopedIgnoredApps: Set<String> = [
        ghosttyBundleID,
        "com.raycast.macos",
        "com.raycast-x.macos",
    ]

    /// System UI overlay processes that should not enter window state (#177).
    private static let ignoredSystemApps: Set<String> = [
        "com.apple.textinputmenuagent",
        "com.apple.textinputswitcher",
        "com.apple.controlcenter",
    ]

    public static func isBuiltInIgnoredApp(
        bundleID: String?
    ) -> Bool {
        guard let bundleID else { return false }
        return ignoredSystemApps.contains(bundleID.lowercased())
    }

    /// Whether window should be ignored from tracking, state, and borders
    /// (#21, #448). An accessory app's raised-layer window with a
    /// title-bar button is a normal window of that app, not a
    /// launcher or HUD, and escapes (#2072); `titlebarButton` is
    /// read only where that branch decides.
    public static func shouldIgnore(
        bundleID: String?,
        layer: Int,
        isAccessory: Bool,
        rules: IgnoreRules,
        titlebarButton: Bool
    ) -> Bool {
        rules.matches(bundleID: bundleID)
            || isBuiltInIgnoredApp(bundleID: bundleID)
            || layer != 0
                && (isAccessory && !titlebarButton
                    || bundleID.map {
                        layerScopedIgnoredApps
                            .contains($0.lowercased())
                    } == true)
    }

    /// Whether the ignore gate asks the window's title-bar button:
    /// the #2072 escape decides only for an accessory app's raised
    /// window. The one copy of the condition — the off-main list
    /// read and the main-actor gate both ask it.
    public static func needsTitlebarButton(
        layer: Int,
        isAccessory: Bool
    ) -> Bool {
        isAccessory && layer != 0
    }

    /// Whether ignore classification depends on CGWindow layer lookup.
    public static func requiresWindowLayers(
        bundleID: String?,
        isAccessory: Bool
    ) -> Bool {
        isAccessory
            || bundleID.map {
                layerScopedIgnoredApps.contains($0.lowercased())
            } == true
    }

    /// Checks if a window ID corresponds to a built-in layer-scoped
    /// ignored panel.
    public static func isBuiltInIgnoredPanel(
        bundleID: String?,
        id: WindowID,
        isAccessory: Bool,
        titlebarButton: Bool
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
            rules: IgnoreRules(),
            titlebarButton: titlebarButton
        )
    }

    /// Batch queries CGWindow layers for all windows of process `pid`
    /// in one call (AGENTS.md).
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

    /// Checks if layer is in the raised panel band: above 0 and
    /// BELOW main-menu level, the ceiling that keeps status-level
    /// chrome out of the panel verdict (#448).
    static func isPanelBandLayer(_ layer: Int) -> Bool {
        layer > 0
            && layer < Int(CGWindowLevelForKey(.mainMenuWindow))
    }

    /// Whether process currently displays a visible ignored panel
    /// (#21, #448). A `tracked` window is none: the gate admitted
    /// it, a buttoned one through the #2072 escape this reading
    /// cannot see.
    public static func hasVisibleIgnoredPanel(
        pid: pid_t,
        bundleID: String?,
        isAccessory: Bool,
        tracked: Set<WindowID>
    ) -> Bool {
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
            let layer =
                info[kCGWindowLayer as String] as? Int ?? 0
            let number = (info[kCGWindowNumber as String] as? Int)
                .flatMap { UInt32(exactly: $0) }.map(WindowID.init)
            return info[kCGWindowOwnerPID as String] as? pid_t
                == pid
                && number.map { !tracked.contains($0) } ?? true
                && isPanelBandLayer(layer)
                && shouldIgnore(
                    bundleID: bundleID,
                    layer: layer,
                    isAccessory: isAccessory,
                    rules: IgnoreRules(),
                    titlebarButton: false
                )
        }
    }
}
