import ApplicationServices
import Foundation

/// User-overridable float rules from the Lua config:
/// `float_rules = { "com.apple.finder:Get Info",
/// "com.apple.calculator" }`. The identity segment is the app's
/// **bundle identifier** (stable across locale and rename — see
/// `AppRef`), not its display name. `"id"` floats every window
/// of the app; `"id:Title"` floats windows whose title contains
/// the substring. The bundle id is lower-cased on ingest (case-
/// insensitive, like LaunchServices); the title fragment keeps
/// its case (a case-sensitive `contains`).
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]

    public init(_ rules: [String] = []) {
        self.rules = rules.map { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2 else {
                return (rule.lowercased(), nil)
            }
            return (String(parts[0]).lowercased(), String(parts[1]))
        }
    }

    /// The rules as originally written (`"id"` or `"id:Title"`)
    /// — used to seed the GUI editor.
    public var rawRules: [String] {
        rules.map { rule in
            rule.title.map { "\(rule.app):\($0)" } ?? rule.app
        }
    }

    /// Whether any rule for this bundle id matches on a title
    /// fragment — the cheap gate before re-running float
    /// detection on a title change (#160).
    public func hasTitleRule(bundleID: String?) -> Bool {
        // Normalize the query too, not just the stored rule:
        // the rule side is lower-cased on ingest, and matching
        // its case-insensitivity here keeps a caller that hands
        // over a raw `NSRunningApplication.bundleIdentifier`
        // from silently missing.
        guard let bundleID = bundleID?.lowercased() else {
            return false
        }
        return rules.contains {
            $0.app == bundleID && $0.title != nil
        }
    }

    public func matches(
        bundleID: String?,
        title: String
    ) -> Bool {
        guard let bundleID = bundleID?.lowercased() else {
            return false
        }
        return rules.contains { rule in
            guard rule.app == bundleID else { return false }
            guard let fragment = rule.title else { return true }
            return title.contains(fragment)
        }
    }

    public static func == (a: FloatRules, b: FloatRules) -> Bool {
        a.rules.map(\.app) == b.rules.map(\.app)
            && a.rules.map(\.title) == b.rules.map(\.title)
    }
}

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
    /// no state entry, no events. Ghostty's quick terminal is
    /// a slide-down panel (non-zero CGWindow layer) that macOS
    /// shows over every space; merely *floating* it still
    /// assigns it a space, and focusing it then drags the user
    /// to that space (issue #21). Hardcoded on purpose: no
    /// general ignore-rule machinery until a second case
    /// exists. Keyed on bundle id, like the user float rules.
    public static func shouldIgnore(
        bundleID: String?,
        layer: Int
    ) -> Bool {
        bundleID == ghosttyBundleID && layer != 0
    }

    /// Whether any ignore rule exists for this app at all —
    /// the cheap gate before every window-list lookup.
    public static func hasIgnoreRule(
        bundleID: String?
    ) -> Bool {
        bundleID == ghosttyBundleID
    }

    /// Window-id variant: skips the CGWindowList lookup for
    /// apps that have no ignore rule at all (the common case
    /// on every reconcile).
    public static func shouldIgnore(
        bundleID: String?,
        id: WindowID
    ) -> Bool {
        guard hasIgnoreRule(bundleID: bundleID) else {
            return false
        }
        return shouldIgnore(
            bundleID: bundleID,
            layer: windowLayer(of: id) ?? 0
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
        // Cheap out before the window-list scan: only apps
        // with an ignore rule can have ignored panels.
        guard hasIgnoreRule(bundleID: bundleID) else {
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
                        as? Int ?? 0
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
