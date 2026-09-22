import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **The title arm resolves from the tracked map and reads the
/// title off the main actor** (#1088). A browser or a terminal
/// storms this notification on the thread that delivers the
/// `CADisplayLink` callback, and both of the arm's old reads —
/// the id and the title — were blocking IPC into that app.
///
/// Driven through `handle`, the arm's real entry, on stubbed
/// seams; the read is captured and pumped by hand.
@Suite("Title arm route (#1088)")
@MainActor
struct TitleArmRouteTests {
    private let element = AXUIElementCreateSystemWide()
    private let pid = pid_t(getpid())
    private let id = WindowID(42)

    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        let needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var titles: [(WindowID, String)] = []
        var logs: [String] = []
        var asked = 0
        var work: [@Sendable () -> Void] = []
        var title: String? = "Hello"

        func drainOne() {
            guard !work.isEmpty else { return }
            work.removeFirst()()
        }
    }

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.logs.append($0) }
        loop.resolveWindowID = { [id] _ in
            box.asked += 1
            return id
        }
        loop.axReads.titleReader = { _ in
            MainActor.assumeIsolated { box.title }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.work.append(work)
        }
        loop.observers[pid] = FakeObserver()
        loop.elements[pid] = [id: element]
        loop.onEvent = { event in
            if case .windowTitleChanged(let id, let title) = event {
                box.titles.append((id, title))
            }
        }
        return (loop, box)
    }

    private func notify(_ loop: EventLoop) {
        loop.handle(
            kAXTitleChangedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
    }

    @Test("A tracked window never asks, and reads off main")
    func trackedWindowReadsOffMain() {
        let (loop, box) = makeLoop()
        notify(loop)
        // Nothing inline: the read is scheduled, not performed,
        // and no round-trip resolved the id.
        #expect(box.asked == 0)
        #expect(box.titles.isEmpty, "delivered inline")
        #expect(box.work.count == 1)
        box.drainOne()
        #expect(box.titles.count == 1)
        #expect(box.titles.first?.0 == id)
        #expect(box.titles.first?.1 == "Hello")
    }

    @Test("A dead element's failed copy is dropped at delivery")
    func deadElementIsDropped() {
        // The liveness the blocking ask gave for free: a
        // destroyed element answers no title, so the arm
        // returned before ever reading. `nil` is the failed
        // copy — never the empty string, which is a real title.
        let (loop, box) = makeLoop()
        box.title = nil
        notify(loop)
        box.drainOne()
        #expect(box.titles.isEmpty, "delivered \(box.titles)")
        #expect(
            box.logs.contains { $0.contains("unreadable at delivery") },
            "no drop line: \(box.logs)"
        )
    }

    @Test("An empty title is a real answer and is delivered")
    func emptyTitleIsDelivered() {
        let (loop, box) = makeLoop()
        box.title = ""
        notify(loop)
        box.drainOne()
        #expect(box.titles.count == 1)
        #expect(box.titles.first?.1 == "")
    }

    @Test("An untracked window is dropped without asking")
    func untrackedIsDroppedWithoutAsking() {
        // Title notifications are registered per WINDOW at
        // track, so an element the map does not carry is a
        // window already released, and no consumer reads an
        // untracked id — a hidden browser (#913) loading pages
        // used to pay the round-trip per notification.
        let (loop, box) = makeLoop()
        loop.elements[pid] = [:]
        notify(loop)
        #expect(box.asked == 0)
        #expect(box.work.isEmpty)
        #expect(box.titles.isEmpty)
    }

    @Test("An ambiguous element asks rather than guessing")
    func ambiguousElementAsks() {
        // Both ids are tracked and one of them owes the bars
        // this title, so the app settles it (#1084's coin flip).
        let (loop, box) = makeLoop()
        loop.elements[pid] = [id: element, WindowID(43): element]
        notify(loop)
        #expect(box.asked == 1)
        box.drainOne()
        #expect(box.titles.first?.0 == id)
    }

    @Test("A storm coalesces to one read plus one re-read")
    func stormCoalesces() {
        // The bars see the LAST title, and the app is read at
        // most twice however fast it retitles.
        let (loop, box) = makeLoop()
        for n in 1...10 {
            box.title = "Page \(n)"
            notify(loop)
        }
        #expect(box.work.count == 1)
        box.drainOne()
        #expect(box.work.count == 1, "no dirty re-read queued")
        box.drainOne()
        #expect(box.work.isEmpty)
        #expect(box.titles.count == 2)
        #expect(box.titles.last?.1 == "Page 10")
    }

    @Test("A read completing after detach delivers nothing")
    func detachedDuringFlightDeliversNothing() {
        let (loop, box) = makeLoop()
        notify(loop)
        loop.observers[pid] = nil
        box.drainOne()
        #expect(box.titles.isEmpty, "delivered \(box.titles)")
    }

    @Test("A window released during the read delivers nothing")
    func releasedDuringFlightDeliversNothing() {
        // The registration is re-checked at delivery, the focus
        // arm's shape: a sweep or a #913 hide can land inside
        // the read's flight.
        let (loop, box) = makeLoop()
        notify(loop)
        loop.elements[pid] = [:]
        box.drainOne()
        #expect(box.titles.isEmpty, "delivered \(box.titles)")
    }
}
