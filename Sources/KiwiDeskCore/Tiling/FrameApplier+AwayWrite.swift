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
    /// frame was written. Sized through the screen's edge band, as every
    /// applier write is (#2894). Never staged in a slide's hold: an
    /// away window is on no Desktop a slide shows. Clears a pending
    /// resend; the caller owns the spring and the stash capture.
    func writeAway(
        _ id: WindowID,
        _ frame: CGRect,
        _ element: AXUIElement,
        _ pid: pid_t,
        landed: @escaping @MainActor (Bool) -> Void
    ) {
        pendingResends[id] = nil
        let band = edgeBand(frame, setSize: true)
        nonisolated(unsafe) let target = element
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
            if same {
                EdgeBandWrite.write(
                    frame,
                    target,
                    nearEdgeOf: band,
                    writer: writer
                )
            }
            holds.endInstant(pid, writer)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { landed(same) }
            }
        }
    }
}
