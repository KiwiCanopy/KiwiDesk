import AppKit

/// One window the WindowServer lists on screen, as a KiwiVision
/// mask reads it (#2103 ruling 21).
struct VisionListedWindow: Equatable {
    let number: CGWindowID
    /// CG global coordinates, top-left origin — AX's orientation.
    let frame: CGRect
}

/// The one WindowServer list read a KiwiVision mask takes: the
/// on-screen normal-level windows of other apps. Never on the
/// switch path — the plate reads it at a settle pass, or when the
/// cache is empty (v2 probe P11: p99 5 ms).
enum VisionWindowList {
    /// Layer 0 only — the shelf and a quick terminal sit above the
    /// plate, SketchyBar and the desktop icons below the windows —
    /// skipping a window drawn at alpha 0 and every window of this
    /// process, whose overlays are normal-level panels (P14); the
    /// one own window that tiles is tracked instead.
    static func read() -> [VisionListedWindow] {
        guard
            let raw = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return [] }
        let own = ProcessInfo.processInfo.processIdentifier
        return raw.compactMap { entry in
            guard
                entry[kCGWindowLayer as String] as? Int == 0,
                (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                let pid = entry[kCGWindowOwnerPID as String] as? Int,
                pid_t(pid) != own,
                let number = entry[kCGWindowNumber as String] as? Int,
                let bounds = entry[kCGWindowBounds as String]
                    as? NSDictionary,
                let frame = CGRect(
                    dictionaryRepresentation: bounds as CFDictionary
                )
            else { return nil }
            return VisionListedWindow(
                number: CGWindowID(number),
                frame: frame
            )
        }
    }
}
