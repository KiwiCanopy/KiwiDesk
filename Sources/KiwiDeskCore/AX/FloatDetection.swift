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
        serverSnapshot(of: id).layer
    }

    /// One window's WindowServer signals — layer, alpha, and
    /// bounds (CG global, top-left-origin coordinates) — read in
    /// a single round trip, so ignore/float/helper classification
    /// shares one snapshot (never query the server in a loop).
    public struct WindowServerSnapshot: Sendable {
        public let layer: Int?
        public let alpha: Double?
        public let bounds: CGRect?
    }

    public static func serverSnapshot(
        of id: WindowID
    ) -> WindowServerSnapshot {
        let list =
            CGWindowListCopyWindowInfo(
                [.optionIncludingWindow],
                CGWindowID(id.raw)
            ) as? [[String: Any]]
        guard let info = list?.first else {
            return WindowServerSnapshot(
                layer: nil,
                alpha: nil,
                bounds: nil
            )
        }
        let bounds =
            (info[kCGWindowBounds as String] as? [String: Any])
            .flatMap {
                CGRect(
                    dictionaryRepresentation: $0 as CFDictionary
                )
            }
        return WindowServerSnapshot(
            layer: info[kCGWindowLayer as String] as? Int,
            alpha: info[kCGWindowAlpha as String] as? Double,
            bounds: bounds
        )
    }

    /// #309: a clearly-non-user helper window — a *raised-layer*
    /// window that is fully transparent or entirely off every
    /// display (CodexBar's 20×20 alpha-0 lifecycle keepalive at
    /// (-5000, 6116)). Such a window must never be tracked: a
    /// tracked float still earns a Space assignment and an App
    /// Bar slot, so the menu-bar app reads as an open app.
    /// Normal-layer (0) windows are never helpers — KiwiDesk
    /// itself parks inactive-space windows off-screen at the
    /// peek corner, and those must stay managed. Track-time
    /// classification: a genuine overlay caught mid fade-in
    /// (alpha still 0) self-heals — it stays untracked for one
    /// beat and the next reconcile pass re-tracks it once
    /// visible.
    public static func isInvisibleHelper(
        layer: Int?,
        alpha: Double?,
        bounds: CGRect?,
        displays: [CGRect]
    ) -> Bool {
        guard let layer, layer != 0 else { return false }
        if alpha == 0 { return true }
        guard let bounds, !displays.isEmpty else {
            return false
        }
        return !displays.contains { $0.intersects(bounds) }
    }

    /// CG global bounds of every active display — the coordinate
    /// space `kCGWindowBounds` reports in (top-left origin, no
    /// Cocoa flip needed).
    public static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard
            CGGetActiveDisplayList(0, nil, &count) == .success,
            count > 0
        else { return [] }
        var ids = [CGDirectDisplayID](
            repeating: 0,
            count: Int(count)
        )
        guard
            CGGetActiveDisplayList(count, &ids, &count) == .success
        else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    /// AX can expose a transient proxy as an auxiliary window even
    /// though no matching WindowServer window exists. Managing that
    /// proxy creates a floating state entry and an AppKit fallback
    /// border around system UI shown at the same location. Real
    /// dialogs and panels have a layer; standard windows may be
    /// absent because they live on another native Space.
    public static func isUnbackedAuxiliary(
        role: String,
        subrole: String,
        layer: Int?
    ) -> Bool {
        layer == nil && shouldFloat(role: role, subrole: subrole)
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
        let layer = AXHelper.windowID(of: element)
            .flatMap { windowLayer(of: $0) }
        return shouldFloat(
            element: element,
            bundleID: bundleID,
            layer: layer,
            rules: rules
        )
    }

    /// Variant for callers that already read the WindowServer layer.
    /// Tracking uses it to keep ignore and float classification on
    /// the same snapshot instead of making two server round trips.
    @MainActor
    public static func shouldFloat(
        element: AXUIElement,
        bundleID: String?,
        layer: Int?,
        rules: FloatRules
    ) -> Bool {
        let title = AXHelper.title(of: element)
        if rules.matches(bundleID: bundleID, title: title) {
            return true
        }
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
