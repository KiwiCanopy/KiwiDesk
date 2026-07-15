import Testing

@testable import KiwiDeskCore

/// Pure routing policy for the private WindowServer notifications
/// (#285 Tier 2). FFI delivery itself is manual-test territory; these
/// tests pin the undocumented IDs and geometry ownership policy.
@Suite("SkyLight border window events")
@MainActor
struct SkyLightWindowEventTests {
    @Test("Registers the current JankyBorders event IDs")
    func eventIDs() {
        #expect(
            Set(SkyLightWindowEvents.Kind.allCases.map(\.rawValue))
                == [804, 806, 807, 808, 811, 815, 816]
        )
    }

    @Test("Move and resize always follow authoritative bounds")
    func geometryEventsFollow() {
        #expect(
            SkyLightWindowEvents.Kind.move.action == .follow
        )
        #expect(
            SkyLightWindowEvents.Kind.resize.action == .follow
        )
    }

    @Test("Unhide refreshes geometry before restoring order")
    func unhideReconciles() {
        #expect(
            SkyLightWindowEvents.Kind.unhide.action
                == .followAndReorder
        )
    }

    @Test("Ordering and visibility events route independently")
    func orderAndVisibility() {
        for kind in [
            SkyLightWindowEvents.Kind.reorder,
            .level,
        ] {
            #expect(kind.action == .reorder)
        }
        for kind in [
            SkyLightWindowEvents.Kind.hide,
            .close,
        ] {
            #expect(kind.action == .hide)
        }
    }

    @Test("Control and geometry preserve arrival order")
    func eventOrder() {
        let window = WindowID(1)
        var scheduled: [SkyLightWindowEventQueue.Work] = []
        var delivered: [SkyLightWindowEventQueue.Event] = []
        let queue = SkyLightWindowEventQueue(
            scheduler: { scheduled.append($0) },
            handler: { delivered.append($0) }
        )
        queue.enqueue(.hide, window: window)
        queue.enqueue(.move, window: window)
        #expect(delivered.isEmpty)
        #expect(scheduled.count == 1)
        scheduled.removeFirst()()
        #expect(
            delivered == [
                .init(kind: .hide, window: window),
                .init(kind: .move, window: window),
            ]
        )

        delivered = []
        queue.enqueue(.move, window: window)
        queue.enqueue(.hide, window: window)
        scheduled.removeFirst()()
        #expect(
            delivered == [
                .init(kind: .move, window: window),
                .init(kind: .hide, window: window),
            ]
        )
    }

    @Test("Geometry coalesces only for the same window")
    func geometryCoalescingScope() {
        let first = WindowID(1)
        let second = WindowID(2)
        var scheduled: [SkyLightWindowEventQueue.Work] = []
        var delivered: [SkyLightWindowEventQueue.Event] = []
        let queue = SkyLightWindowEventQueue(
            scheduler: { scheduled.append($0) },
            handler: { delivered.append($0) }
        )

        queue.enqueue(.move, window: first)
        queue.enqueue(.resize, window: first)
        scheduled.removeFirst()()
        #expect(
            delivered == [
                .init(kind: .resize, window: first)
            ]
        )

        delivered = []
        queue.enqueue(.move, window: first)
        queue.enqueue(.resize, window: second)
        queue.enqueue(.resize, window: first)
        scheduled.removeFirst()()

        #expect(
            delivered == [
                .init(kind: .move, window: first),
                .init(kind: .resize, window: second),
                .init(kind: .resize, window: first),
            ]
        )
    }

    @Test("Reentrant delivery waits behind the current batch")
    func reentrantDeliveryOrder() {
        let window = WindowID(1)
        var scheduled: [SkyLightWindowEventQueue.Work] = []
        var delivered: [SkyLightWindowEventQueue.Event] = []
        let box = WindowEventQueueBox()
        let queue = SkyLightWindowEventQueue(
            scheduler: { scheduled.append($0) },
            handler: { event in
                delivered.append(event)
                if event.kind == .hide {
                    box.queue?.enqueue(.move, window: window)
                }
            }
        )
        box.queue = queue

        queue.beginDrain()
        queue.enqueue(.hide, window: window)
        queue.enqueue(.reorder, window: window)
        queue.endDrain()

        #expect(scheduled.isEmpty)
        #expect(
            delivered == [
                .init(kind: .hide, window: window),
                .init(kind: .reorder, window: window),
                .init(kind: .move, window: window),
            ]
        )
    }
}

@MainActor
private final class WindowEventQueueBox {
    weak var queue: SkyLightWindowEventQueue?
}
