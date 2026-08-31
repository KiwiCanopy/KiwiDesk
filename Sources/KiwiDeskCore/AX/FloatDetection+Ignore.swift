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
    /// (#21, #448).
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

    /// Checks if layer is in raised panel band below main-menu level (#448).
    static func isPanelBandLayer(_ layer: Int) -> Bool {
        layer > 0
            && layer < Int(CGWindowLevelForKey(.mainMenuWindow))
    }

    /// Whether process currently displays a visible ignored panel (#21, #448).
    public static func hasVisibleIgnoredPanel(
        pid: pid_t,
        bundleID: String?,
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
        let list =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        return list.contains { info in
            let layer =
                info[kCGWindowLayer as String] as? Int ?? 0
            return info[kCGWindowOwnerPID as String] as? pid_t
                == pid
                && isPanelBandLayer(layer)
                && shouldIgnore(
                    bundleID: bundleID,
                    layer: layer,
                    isAccessory: isAccessory,
                    rules: IgnoreRules()
                )
        }
    }
}
