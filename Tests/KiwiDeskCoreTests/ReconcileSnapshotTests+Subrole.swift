import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The subrole the show verdict reads (#1788 item 5) is re-filed
/// by the same reconcile readings as the fullscreen flag. Beside
/// the suite whose fixture it shares, split for the file ceiling.
extension ReconcileSnapshotTests {
    private func reading(_ subrole: String) -> TrackedReading {
        TrackedReading(
            fullscreen: false,
            subrole: subrole,
            frame: .zero,
            autoReason: nil,
            traits: nil
        )
    }

    /// A window adopted titled can drop its title bar in place
    /// as it starts presenting (#1788 item 5): a reading re-files
    /// the subrole, change-only, and a failed (empty) read is no
    /// evidence and files nothing.
    @Test("a subrole change lands, a failed read does not")
    func subroleChangeLands() {
        let (loop, box) = makeLoop()
        loop.detectedSubroles[first] = "AXStandardWindow"
        loop.recheckFloat(
            id: first,
            pid: pid,
            app: ref,
            reading: reading("AXUnknown")
        )
        #expect(box.events.contains("subrole w41 AXUnknown"))
        box.events = []
        for read in ["AXUnknown", ""] {
            loop.recheckFloat(
                id: first,
                pid: pid,
                app: ref,
                reading: reading(read)
            )
        }
        #expect(!box.events.contains { $0.hasPrefix("subrole") })
        #expect(loop.detectedSubroles[first] == "AXUnknown")
    }

    /// The fabricated elements answer no subrole: neither reconcile
    /// path files that over the subrole adoption read.
    @Test("a failed subrole read files nothing on either path")
    func failedReadFilesNothing() {
        for offMain in [true, false] {
            let (loop, box) = makeLoop()
            loop.detectedSubroles[first] = "AXStandardWindow"
            if offMain {
                loop.reconcileOffMain(pid: pid, app: ref)
            } else {
                loop.reconcile(pid: pid, app: ref)
            }
            #expect(
                !box.events.contains { $0.hasPrefix("subrole") },
                "\(offMain)"
            )
            #expect(loop.detectedSubroles[first] == "AXStandardWindow")
        }
    }
}
