import CoreGraphics

/// Sets a foreign-process window's server-side stacking level so a
/// floating window renders above every tiled window regardless of
/// which window is focused (#418).
///
/// This is the SkyLight fast path. Unlike frame changes there is no
/// public Accessibility equivalent — AX cannot set a window level —
/// so when the private symbol does not resolve (`isAvailable` is
/// false) callers fall back to re-raising floats on focus, not to a
/// second implementation here (see `KiwiCore+ZOrderFloats`).
///
/// Deliberately not `@MainActor`: the SkyLight call is thread-safe
/// window-server IPC, matching `WindowControl`.
public enum WindowLevel {
    /// The level macOS uses for its own floating panels — above the
    /// tiled plane. Promoted floating windows sit here.
    static let floating = CGWindowLevelForKey(.floatingWindow)
    /// Ordinary application windows: the tiled plane.
    static let normal = CGWindowLevelForKey(.normalWindow)

    /// Whether the private level-set symbol resolved. False on a
    /// future macOS that drops it — the caller then leans on the AX
    /// re-raise fallback (§5 guardrail: every fast path has one).
    public static var isAvailable: Bool {
        SkyLight.setWindowLevel != nil
    }

    /// Applies `level` to the window with `id`. Fire-and-forget: the
    /// SkyLight status register is junk, so it is never read (#357).
    /// A no-op when the symbol or connection is missing.
    static func set(_ level: CGWindowLevel, of id: CGWindowID) {
        guard let cid = SkyLight.connection,
            let fn = SkyLight.setWindowLevel
        else { return }
        _ = fn(cid, id, Int32(level))
    }
}
