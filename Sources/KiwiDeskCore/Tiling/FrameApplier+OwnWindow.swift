import AppKit

extension FrameApplier {
    /// Moves KiwiDesk's own window `id` to `frame` (AX coordinates)
    /// through AppKit, inside the caller's turn; false where no own
    /// window carries that number. AppKit sends the frame at the
    /// turn's commit, so a switch's park lands with the switch
    /// rather than on a later main-queue turn (#1956).
    static func moveOwnWindow(
        _ id: WindowID,
        _ frame: CGRect,
        _ setSize: Bool
    ) -> Bool {
        guard
            let window = NSApplication.shared.window(
                withWindowNumber: Int(id.raw)
            )
        else { return false }
        let size = setSize ? frame.size : window.frame.size
        let cocoa = GeometryUtils.flip(
            CGRect(origin: frame.origin, size: size),
            primaryHeight: GeometryUtils.primaryHeight
        )
        window.setFrame(cocoa, display: false)
        return true
    }
}
