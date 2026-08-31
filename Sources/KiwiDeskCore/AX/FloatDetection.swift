import ApplicationServices
import Foundation

/// Classifies windows from AX and CGWindow signals for tiling or floating.
public enum FloatDetection {
    /// Subroles identifying auxiliary windows (dialogs, panels, PIP overlays).
    public static func shouldFloat(
        role: String,
        subrole: String
    ) -> Bool {
        guard role == kAXWindowRole else { return true }
        return subrole != kAXStandardWindowSubrole
    }

    /// Evaluates role/subrole and WindowServer layer: layer != 0
    /// never tiles, even when the subrole momentarily reads
    /// AXStandardWindow — apps mid-launch report unreliable
    /// subroles.
    public static func shouldFloat(
        role: String,
        subrole: String,
        layer: Int
    ) -> Bool {
        layer != 0 || shouldFloat(role: role, subrole: subrole)
    }

    /// Returns CGWindow layer for window ID, or nil if unlisted.
    public static func windowLayer(of id: WindowID) -> Int? {
        serverSnapshot(of: id).layer
    }

    /// Snapshot of window properties from WindowServer
    /// (`kCGWindowBounds`, CG global top-left coordinates) — one
    /// round trip shared by ignore/float/helper classification;
    /// never query the server in a loop.
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

    /// Detects non-user helper windows on raised layers (#309):
    /// fully transparent or entirely off-screen. Normal-layer (0)
    /// windows are never helpers — KiwiDesk itself parks
    /// inactive-space windows off-screen, and those must stay
    /// managed. An overlay caught mid fade-in self-heals on the
    /// next reconcile.
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

    /// CG global bounds of all active displays.
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

    /// Detects unbacked auxiliary proxy windows: AX can expose a
    /// transient proxy with no WindowServer window behind it, and
    /// managing it draws a fallback border around system UI. Real
    /// dialogs have a layer; standard windows may be absent
    /// because they live on another native Space.
    public static func isUnbackedAuxiliary(
        role: String,
        subrole: String,
        layer: Int?
    ) -> Bool {
        layer == nil && shouldFloat(role: role, subrole: subrole)
    }

    /// Evaluates if AX element should float using window rules (`FloatRules`).
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

    /// Float decision given cached WindowServer layer (`FloatRules`).
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
    /// Detects macOS native tab group (`AXTabGroup`).
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
