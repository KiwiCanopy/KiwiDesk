import CoreGraphics

/// WindowServer bounds query wrapper for focus border reconciliation (#594).
extension SkyLight {
    /// Authoritative WindowServer bounds (AX coordinates) for `wid`, or nil.
    static func windowBounds(_ wid: CGWindowID) -> CGRect? {
        guard let connection,
            let getBounds = getWindowBounds
        else { return nil }
        var frame = CGRect.zero
        guard
            getBounds(connection, wid, &frame) == .success
        else { return nil }
        return frame
    }
}
