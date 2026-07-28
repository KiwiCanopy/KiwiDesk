import CoreGraphics

/// Composed WindowServer bounds read for the focus border's
/// reconcile path (#594), mirroring `windowCornerRadius`'s shape:
/// the raw `SLSGetWindowBounds` symbol stays in `+Borders`; this
/// wraps the connection guard and out-param so consumers get one
/// optional-returning call instead of hand-composing the
/// primitives (a second hand-rolled copy is how the `.success`
/// check gets lost). A nil answer falls back per the OS-layer
/// contract — here, the caller skips the reconcile and the AX
/// echo path keeps updating the overlay.
extension SkyLight {
    /// The authoritative WindowServer bounds (AX coordinates)
    /// for `wid`, or `nil` when the private surface is
    /// unavailable or the query fails.
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
