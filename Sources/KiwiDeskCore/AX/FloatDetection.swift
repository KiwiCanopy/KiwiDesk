import ApplicationServices
import Foundation

/// Classifies windows from AX and CGWindow signals: float
/// instead of tile, or ignore entirely (never managed).
public enum FloatDetection {
    /// Subroles that identify auxiliary windows (dialogs,
    /// panels, PIP overlays). Everything that is not a
    /// standard window floats by default.
    public static func shouldFloat(
        role: String,
        subrole: String
    ) -> Bool {
        guard role == kAXWindowRole else { return true }
        return subrole != kAXStandardWindowSubrole
    }

    /// Subrole check plus the window's CGWindow layer. Normal
    /// windows live on layer 0; panels and overlays (Ghostty's
    /// quick terminal: layer 3) sit higher and never tile, even
    /// when their subrole momentarily reads AXStandardWindow
    /// (apps mid-launch report unreliable subroles).
    public static func shouldFloat(
        role: String,
        subrole: String,
        layer: Int
    ) -> Bool {
        layer != 0 || shouldFloat(role: role, subrole: subrole)
    }

    /// CGWindow layer of a window, nil if the system does not
    /// list it (e.g. another native Space).
    public static func windowLayer(of id: WindowID) -> Int? {
        let list =
            CGWindowListCopyWindowInfo(
                [.optionIncludingWindow],
                CGWindowID(id.raw)
            ) as? [[String: Any]]
        return list?.first?[kCGWindowLayer as String] as? Int
    }

    /// Bundle id of the one hardcoded ignored app (see below).
    private static let ghosttyBundleID = "com.mitchellh.ghostty"

    /// Windows KiwiDesk must not manage at all — no tracking,
    /// state entry, space assignment, or events. User rules are
    /// app-wide. Ghostty's built-in stays layer-scoped because
    /// only its quick-terminal panel must be ignored (#21).
    public static func shouldIgnore(
        bundleID: String?,
        layer: Int,
        rules: IgnoreRules
    ) -> Bool {
        rules.matches(bundleID: bundleID)
            || bundleID == ghosttyBundleID && layer != 0
    }

    /// Only Ghostty's built-in rule depends on CGWindow layer.
    /// User rules match the whole app and need no server scan.
    public static func requiresWindowLayers(
        bundleID: String?
    ) -> Bool {
        bundleID == ghosttyBundleID
    }

    /// Window-id check for Ghostty's built-in ignored panel.
    /// User-ignored apps do not use the panel-dismiss focus
    /// workaround: every window in those apps is ignored.
    public static func isBuiltInIgnoredPanel(
        bundleID: String?,
        id: WindowID
    ) -> Bool {
        guard requiresWindowLayers(bundleID: bundleID) else {
            return false
        }
        return shouldIgnore(
            bundleID: bundleID,
            layer: windowLayer(of: id) ?? 0,
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
        bundleID: String?
    ) -> Bool {
        // Cheap out before the window-list scan: only Ghostty
        // has the built-in layer-scoped panel workaround.
        guard requiresWindowLayers(bundleID: bundleID) else {
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
                    rules: IgnoreRules()
                )
        }
    }

    /// Full decision for a live AX element, including user
    /// rules. PIP windows (subrole AXFloatingWindow) float
    /// automatically via the subrole check.
    @MainActor
    public static func shouldFloat(
        element: AXUIElement,
        bundleID: String?,
        rules: FloatRules
    ) -> Bool {
        let title = AXHelper.title(of: element)
        if rules.matches(bundleID: bundleID, title: title) {
            return true
        }
        let layer = AXHelper.windowID(of: element)
            .flatMap { windowLayer(of: $0) }
        return shouldFloat(
            role: AXHelper.role(of: element),
            subrole: AXHelper.subrole(of: element),
            layer: layer ?? 0
        )
    }
}

extension AXHelper {
    /// Detects macOS native tabs (Finder, Terminal, Safari).
    /// A tab group is a single `NSWindow` and is treated as
    /// ONE tiling unit — tabs are never split apart (see
    /// 03_Layout_Engine §6.1).
    @MainActor
    public static func hasNativeTabs(
        _ element: AXUIElement
    ) -> Bool {
        guard
            let children = attribute(
                element,
                kAXChildrenAttribute,
                as: [AXUIElement].self
            )
        else { return false }
        return children.contains {
            role(of: $0) == "AXTabGroup"
        }
    }
}
