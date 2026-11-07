import ApplicationServices
import CoreGraphics
import Foundation

extension FrameApplier {
    /// Writes a frame to a window on a Desktop nobody shows, through
    /// an element kept since it left (#3048). Off the main actor on
    /// the app's queue with Enhanced UI held off, since the id
    /// re-check is IPC into the app and a raw write glides about
    /// 300 ms (macOS 27.2, TextEdit). `landed` runs on the main actor
    /// with whether the element still named `id`, which is whether the
    /// frame was written. Clears a pending resend; the caller owns the
    /// spring and the stash capture.
    func writeAway(
        _ id: WindowID,
        _ frame: CGRect,
        _ element: AXUIElement,
        _ pid: pid_t,
        landed: @escaping @MainActor (Bool) -> Void
    ) {
        pendingResends[id] = nil
        nonisolated(unsafe) let target = element
        nonisolated(unsafe) let landed = landed
        let writer = writer
        let holds = enhancedUI
        holds.noteQueued(
            pid,
            atRest: enhancedUIAtRest(pid),
            instant: true
        )
        queue(for: pid).async {
            holds.beginInstant(pid, writer)
            let same = writer.windowID(target) == id
            if same { writer.setFrame(frame, target) }
            holds.endInstant(pid, writer)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { landed(same) }
            }
        }
    }
}
