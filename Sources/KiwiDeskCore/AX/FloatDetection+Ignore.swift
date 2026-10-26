import ApplicationServices
import Foundation

/// Window ignore classification and layer-scoped panel detection
/// (`FloatDetection.swift`).
extension FloatDetection {
    private static let ghosttyBundleID = "com.mitchellh.ghostty"

    /// Layer-scoped ignored apps: only raised-layer panels are ignored
    /// (#21, #448). The value says whether a raised window with a
    /// title-bar button escapes, as Ghostty's config error does
    /// beside its buttonless quick terminal (#2067) — and a window
    /// at the modal-panel level, its update alert, which the quick
    /// terminal never takes (3 shown, 101 hidden; #2200).
    private static let layerScopedIgnoredApps: [String: Bool] = [
        ghosttyBundleID: true,
        "com.raycast.macos": false,
        "com.raycast-x.macos": false,
    ]

    /// System UI overlay processes that should not enter window state (#177).
    private static let ignoredSystemApps: Set<String> = [
        "com.apple.textinputmenuagent",
        "com.apple.textinputswitcher",
        "com.apple.controlcenter",
    ]

    /// The screen-saver level: a window at or above it is a HUD or
    /// a full-screen overlay, whatever its app, and is never
    /// ADOPTED (#2069).
    static let screenSaverLayer = Int(
        CGWindowLevelForKey(.screenSaverWindow)
    )

    /// The layer the gate judges: a window tracked before it rose
    /// to the screen-saver level keeps the verdict it had below
    /// it, since the sweep would read its removal as a close.
    static func judgedLayer(_ layer: Int, tracked: Bool) -> Int {
        tracked ? min(layer, screenSaverLayer - 1) : layer
    }

    /// Whether the built-in table ignores `bundleID`'s raised-layer
    /// windows — a table read, never a window's verdict (#1685).
    public static func ignoresRaisedWindows(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return layerScopedIgnoredApps[bundleID.lowercased()] != nil
    }

    public static func isBuiltInIgnoredApp(
        bundleID: String?
    ) -> Bool {
        guard let bundleID else { return false }
        return ignoredSystemApps.contains(bundleID.lowercased())
    }

    /// Whether window should be ignored from tracking, state, and borders
    /// (#21, #448). An accessory app's raised-layer window with a
    /// title-bar button is a normal window of that app, not a
    /// launcher or HUD, and escapes (#2072), as Ghostty's does
    /// (#2067); `titlebarButton` is read only where
    /// `needsTitlebarButton` says one of them decides.
    public static func shouldIgnore(
        bundleID: String?,
        layer: Int,
        isAccessory: Bool,
        rules: IgnoreRules,
        titlebarButton: Bool
    ) -> Bool {
        rules.matches(bundleID: bundleID)
            || isBuiltInIgnoredApp(bundleID: bundleID)
            || layer >= screenSaverLayer
            || layer != 0
                && (isAccessory && !titlebarButton
                    || ignoresRaisedWindows(bundleID: bundleID)
                        && !(escapesWithButton(bundleID)
                            && (titlebarButton || layer == modalPanelLayer)))
    }

    /// The modal-panel level: an app's own alert, never a
    /// launcher or HUD (#2200).
    static let modalPanelLayer = Int(
        CGWindowLevelForKey(.modalPanelWindow)
    )

    private static func escapesWithButton(_ bundleID: String?) -> Bool {
        bundleID.flatMap { layerScopedIgnoredApps[$0.lowercased()] }
            == true
    }

    /// Whether the ignore gate asks the window's title-bar button:
    /// the #2072 escape decides only for an accessory app's raised
    /// window, and for Ghostty's (#2067), and never for a system
    /// dialog, which a launcher draws with buttons — Spotlight's
    /// panel on macOS 27 (#2239). The one copy of the condition,
    /// which every reader asks (`TitlebarButtonWiringTests` is the
    /// census); `subrole` is read only where the rest holds.
    public static func needsTitlebarButton(
        layer: Int,
        isAccessory: Bool,
        bundleID: String?,
        subrole: @autoclosure () -> String
    ) -> Bool {
        layer != 0 && (isAccessory || escapesWithButton(bundleID))
            && subrole() != kAXSystemDialogSubrole
    }

    /// Whether ignore classification depends on CGWindow layer lookup.
    public static func requiresWindowLayers(
        bundleID: String?,
        isAccessory: Bool
    ) -> Bool {
        isAccessory
            || ignoresRaisedWindows(bundleID: bundleID)
    }

    /// Whether an untracked window of `layer` is a built-in
    /// ignored panel — a layer-scoped one, or any app's at the
    /// screen-saver level (#2069).
    public static func isBuiltInIgnoredPanel(
        bundleID: String?,
        layer: Int,
        isAccessory: Bool,
        titlebarButton: Bool
    ) -> Bool {
        guard
            layer >= screenSaverLayer
                || requiresWindowLayers(
                    bundleID: bundleID,
                    isAccessory: isAccessory
                )
        else {
            return false
        }
        return shouldIgnore(
            bundleID: bundleID,
            layer: layer,
            isAccessory: isAccessory,
            rules: IgnoreRules(),
            titlebarButton: titlebarButton
        )
    }

    /// The layer of each window an off-main list read names: one
    /// SkyLight level per window, else the whole-list read once.
    /// The list read waits on this process's pending window updates
    /// while holding the connection lock, which a main-actor commit
    /// then waits ~500 ms behind (#2531).
    static func layerReader(pid: pid_t) -> (WindowID) -> Int? {
        guard SkyLight.readsWindowLevel else {
            let layers = windowLayers(pid: pid)
            return { layers[$0] }
        }
        return { SkyLight.windowLevel(CGWindowID($0.raw)) }
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
    /// it. An untracked one states the title-bar button the #2072
    /// escape decides on, through `subrole` and `titlebarButton`
    /// (#2344, #2239).
    public static func hasVisibleIgnoredPanel(
        pid: pid_t,
        bundleID: String?,
        isAccessory: Bool,
        tracked: Set<WindowID>,
        subrole: (WindowID) -> String,
        titlebarButton: (WindowID) -> Bool
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
            guard info[kCGWindowOwnerPID as String] as? pid_t == pid
            else { return false }
            return isVisibleIgnoredPanel(
                id: (info[kCGWindowNumber as String] as? Int)
                    .flatMap { UInt32(exactly: $0) }.map(WindowID.init),
                layer: info[kCGWindowLayer as String] as? Int ?? 0,
                bundleID: bundleID,
                isAccessory: isAccessory,
                tracked: tracked,
                subrole: subrole,
                titlebarButton: titlebarButton
            )
        }
    }

    /// One listed window's verdict for `hasVisibleIgnoredPanel`:
    /// untracked, in the panel band, and ignored by the gate's own
    /// predicate — its button asked only where
    /// `needsTitlebarButton` says it decides, and a window with no
    /// number has none.
    static func isVisibleIgnoredPanel(
        id: WindowID?,
        layer: Int,
        bundleID: String?,
        isAccessory: Bool,
        tracked: Set<WindowID>,
        subrole: (WindowID) -> String,
        titlebarButton: (WindowID) -> Bool
    ) -> Bool {
        guard id.map({ !tracked.contains($0) }) ?? true,
            isPanelBandLayer(layer)
        else { return false }
        let button =
            id.map {
                needsTitlebarButton(
                    layer: layer,
                    isAccessory: isAccessory,
                    bundleID: bundleID,
                    subrole: subrole($0)
                ) && titlebarButton($0)
            } == true
        return shouldIgnore(
            bundleID: bundleID,
            layer: layer,
            isAccessory: isAccessory,
            rules: IgnoreRules(),
            titlebarButton: button
        )
    }
}
