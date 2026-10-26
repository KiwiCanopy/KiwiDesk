import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The one WindowServer stream (#2275): consumers register their
/// windows, the watch requests the union, and an event fans out by
/// phase — frames, restacks, hides — in `Consumer` order, the
/// mark ahead of the ring and KiwiVision's plate after it
/// (borders.md ▸ KiwiVision).
@Suite("WindowServer watch")
@MainActor
struct WindowServerWatchTests {
    private let w1 = WindowID(1)
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    /// A watch recording every hook call, in order.
    private func recordingWatch() -> (WindowServerWatch, () -> [String]) {
        let watch = WindowServerWatch()
        watch.readWindowBounds = { [frame] _ in frame }
        final class Log { var calls: [String] = [] }
        let log = Log()
        for consumer in WindowServerWatch.Consumer.allCases {
            let name = "\(consumer)"
            var hooks = WindowServerWatch.Hooks()
            if consumer != .vision {
                hooks.frame = { _, _, _ in log.calls.append(name + ".frame") }
            }
            hooks.restack = { _ in log.calls.append(name + ".restack") }
            hooks.hide = { _ in log.calls.append(name + ".hide") }
            watch.connect(consumer, hooks)
        }
        return (watch, { log.calls })
    }

    /// The overflow mark (#2235) rides beside the sticky mark,
    /// both above the ring they stack over.
    @Test("the consumers fan out mark, overflow, ring, then vision")
    func consumerOrder() {
        #expect(
            WindowServerWatch.Consumer.allCases
                == [.mark, .overflow, .ring, .vision]
        )
    }

    @Test("an event fans out by phase, in consumer order")
    func phaseOrder() {
        let (watch, calls) = recordingWatch()
        for consumer in WindowServerWatch.Consumer.allCases {
            watch.request([w1], for: consumer)
        }
        watch.handle(.unhide, window: w1)
        #expect(
            calls() == [
                "mark.frame", "overflow.frame", "ring.frame",
                "mark.restack", "overflow.restack", "ring.restack",
                "vision.restack",
            ]
        )
        let (reorder, reordered) = recordingWatch()
        for consumer in WindowServerWatch.Consumer.allCases {
            reorder.request([w1], for: consumer)
        }
        reorder.handle(.reorder, window: w1)
        #expect(
            reordered() == [
                "mark.restack", "overflow.restack", "ring.restack",
                "vision.restack",
            ]
        )
        let (hide, hidden) = recordingWatch()
        hide.request([w1], for: .ring)
        hide.handle(.hide, window: w1)
        #expect(hidden() == ["ring.hide"])
    }

    @Test("only the window's own hearers hear it; stale ones drop")
    func onlyHearersHear() {
        let (watch, calls) = recordingWatch()
        watch.request([w1], for: .vision)
        watch.request([WindowID(2)], for: .ring)
        watch.handle(.reorder, window: w1)
        #expect(calls() == ["vision.restack"])
        watch.handle(.reorder, window: WindowID(9))
        #expect(calls() == ["vision.restack"])
    }

    @Test("kept windows are requested and never delivered")
    func keptAreRequestedNotDelivered() {
        let (watch, calls) = recordingWatch()
        var requested: Set<WindowID> = []
        watch.override = {
            requested = $0
            return true
        }
        watch.request([WindowID(2)], for: .ring, keeping: [w1])
        watch.request([WindowID(3)], for: .mark)
        #expect(requested == [w1, WindowID(2), WindowID(3)])
        watch.handle(.reorder, window: w1)
        #expect(calls().isEmpty)
    }

    @Test("one bounds read per event, none while animating")
    func oneGatedRead() {
        let (watch, calls) = recordingWatch()
        var reads = 0
        watch.readWindowBounds = { [frame] _ in
            reads += 1
            return frame
        }
        watch.request([w1], for: .mark)
        watch.request([w1], for: .ring)
        watch.isAnimating = { _ in true }
        watch.handle(.move, window: w1)
        #expect(reads == 0)
        #expect(calls().isEmpty)
        watch.isAnimating = { _ in false }
        watch.handle(.move, window: w1)
        #expect(reads == 1)
        #expect(calls() == ["mark.frame", "ring.frame"])
        // A window only the plate hears costs no read at all.
        let (plate, _) = recordingWatch()
        var plateReads = 0
        plate.readWindowBounds = { [frame] _ in
            plateReads += 1
            return frame
        }
        plate.request([w1], for: .vision)
        plate.handle(.move, window: w1)
        #expect(plateReads == 0)
    }

    @Test("hears answers per consumer, only on a live stream")
    func hearsPerConsumer() {
        let watch = WindowServerWatch()
        watch.request([w1], for: .ring)
        #expect(!watch.hears(w1, as: .ring), "not started")
        watch.override = { _ in true }
        watch.request([w1], for: .ring)
        #expect(watch.hears(w1, as: .ring))
        #expect(!watch.hears(w1, as: .mark))
    }

    @Test("stop drops every registration")
    func stopDropsAll() {
        let (watch, calls) = recordingWatch()
        watch.override = { _ in true }
        watch.request([w1], for: .mark)
        watch.request([w1], for: .vision)
        #expect(watch.isActive)
        watch.stop()
        #expect(watch.requested(by: .mark).isEmpty)
        #expect(watch.requested(by: .vision).isEmpty)
        watch.handle(.reorder, window: w1)
        #expect(calls().isEmpty)
        #expect(!watch.isActive)
    }

    @Test("an empty request before any attach reports nothing")
    func emptyFirstRequestIsSilent() {
        let watch = WindowServerWatch()
        var lines: [String] = []
        watch.onLog = { lines.append($0) }
        watch.start()
        watch.request([], for: .mark)
        #expect(lines.isEmpty)
        #expect(!watch.triedSource)
        watch.stop()
    }

    /// On the verdict path the override skips: the lever's line,
    /// then a stop that must not report again.
    @Test("a stop reports no tracking state")
    func stopIsSilent() {
        let watch = WindowServerWatch()
        var lines: [String] = []
        watch.onLog = { lines.append($0) }
        watch.trackingDisabled = true
        watch.start()
        watch.request([w1], for: .mark)
        #expect(lines.count == 1)
        lines = []
        watch.stop()
        #expect(lines.isEmpty)
    }
}
