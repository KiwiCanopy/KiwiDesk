import CoreGraphics

/// WindowServer bounds query wrapper for focus border
/// reconciliation (#594): wraps the connection guard and
/// out-param so consumers get one optional-returning call — a
/// second hand-rolled copy is how the `.success` check gets
/// lost. On nil the caller skips the reconcile and the AX echo
/// path keeps updating the overlay.
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
