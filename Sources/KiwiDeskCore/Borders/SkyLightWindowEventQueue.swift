import Foundation

/// Main-actor delivery queue behind the WindowServer event pump.
/// Events produced while `nextEvent` drains flush synchronously at
/// the end; callbacks arriving outside that drain share one scheduled
/// flush. A handler may enqueue reentrantly without jumping ahead of
/// events already present in the current batch.
@MainActor
final class SkyLightWindowEventQueue {
    struct Event: Equatable {
        var kind: SkyLightWindowEvents.Kind
        let window: WindowID
    }

    typealias Work = @MainActor @Sendable () -> Void
    typealias Scheduler = @MainActor (@escaping Work) -> Void
    typealias Handler = @MainActor (Event) -> Void

    private let scheduler: Scheduler
    private let handler: Handler
    private var events: [Event] = []
    private var isDraining = false
    private var isFlushing = false
    private var flushScheduled = false

    init(
        scheduler: @escaping Scheduler = {
            DispatchQueue.main.async(execute: $0)
        },
        handler: @escaping Handler
    ) {
        self.scheduler = scheduler
        self.handler = handler
    }

    func beginDrain() {
        isDraining = true
    }

    func endDrain() {
        isDraining = false
        flush()
    }

    func enqueue(
        _ kind: SkyLightWindowEvents.Kind,
        window: WindowID
    ) {
        if kind.isGeometry,
            let last = events.indices.last,
            events[last].window == window,
            events[last].kind.isGeometry
        {
            events[last].kind = kind
        } else {
            events.append(Event(kind: kind, window: window))
        }
        guard !isDraining, !isFlushing else { return }
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        scheduler { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        guard !isDraining, !isFlushing else { return }
        flushScheduled = false
        isFlushing = true
        defer {
            isFlushing = false
            if !events.isEmpty { scheduleFlush() }
        }
        while !events.isEmpty {
            let batch = events
            events = []
            for event in batch { handler(event) }
        }
    }
}
