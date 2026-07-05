import ApplicationServices
import Foundation

/// User-overridable float rules from the Lua config:
/// `float_rules = { "Finder:Get Info", "Calculator" }`.
/// `"App"` floats every window of the app; `"App:Title"`
/// floats windows whose title contains the substring.
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]

    public init(_ rules: [String] = []) {
        self.rules = rules.map { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2 else {
                return (rule, nil)
            }
            return (String(parts[0]), String(parts[1]))
        }
    }

    /// The rules as originally written (`"App"` or
    /// `"App:Title"`) — used to seed the GUI editor.
    public var rawRules: [String] {
        rules.map { rule in
            rule.title.map { "\(rule.app):\($0)" } ?? rule.app
        }
    }

    public func matches(app: String, title: String) -> Bool {
        rules.contains { rule in
            guard rule.app == app else { return false }
            guard let fragment = rule.title else { return true }
            return title.contains(fragment)
        }
    }

    public static func == (a: FloatRules, b: FloatRules) -> Bool {
        a.rules.map(\.app) == b.rules.map(\.app)
            && a.rules.map(\.title) == b.rules.map(\.title)
    }
}

/// Decides whether a window should float instead of tile.
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

    /// Windows KiwiDesk must not manage at all — no tracking,
    /// no state entry, no events. Ghostty's quick terminal is
    /// a slide-down panel (non-zero CGWindow layer) that macOS
    /// shows over every space; merely *floating* it still
    /// assigns it a space, and focusing it then drags the user
    /// to that space (issue #21). Hardcoded on purpose: no
    /// general ignore-rule machinery until a second case
    /// exists.
    public static func shouldIgnore(
        appName: String,
        layer: Int
    ) -> Bool {
        appName == "Ghostty" && layer != 0
    }

    /// Live-element variant of `shouldIgnore(appName:layer:)`.
    @MainActor
    public static func shouldIgnore(
        element: AXUIElement,
        appName: String
    ) -> Bool {
        let layer = AXHelper.windowID(of: element)
            .flatMap { windowLayer(of: $0) }
        return shouldIgnore(
            appName: appName,
            layer: layer ?? 0
        )
    }

    /// Full decision for a live AX element, including user
    /// rules. PIP windows (subrole AXFloatingWindow) float
    /// automatically via the subrole check.
    @MainActor
    public static func shouldFloat(
        element: AXUIElement,
        appName: String,
        rules: FloatRules
    ) -> Bool {
        let title = AXHelper.title(of: element)
        if rules.matches(app: appName, title: title) {
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
