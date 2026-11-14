import CoreGraphics
import Foundation
import os

/// What `TouchGestures` holds of the machine reader — the seam a
/// test replaces.
protocol TouchReaderHandle: AnyObject {
    func stop()
}

/// The MultitouchSupport reader (#1873). It reads, never
/// swallows: the framework hands every frame to every listener, so
/// a swipe macOS answers is kept from macOS by the pointer tap,
/// which reads the finger count this reader publishes
/// (`TouchFingerCount`).
///
/// Frames arrive on the framework's own thread, one per device;
/// each device has its own pure `TrackpadGestureRouter`, run there,
/// and recognized gestures reach the main queue in order. At most
/// one reader runs: the C callback carries no context, so it finds
/// the reader through `current`.
final class TouchReader: TouchReaderHandle, @unchecked Sendable {
    typealias Deliver = @Sendable ([TrackpadGestureEvent]) -> Void

    private static let current = OSAllocatedUnfairLock<TouchReader?>(
        initialState: nil
    )

    private let deliver: Deliver
    private let list: MultitouchSupport.DeviceList
    private let routers = OSAllocatedUnfairLock<[UInt: TrackpadGestureRouter]>(
        initialState: [:]
    )

    private init(
        deliver: @escaping Deliver,
        list: MultitouchSupport.DeviceList
    ) {
        self.deliver = deliver
        self.list = list
    }

    /// Starts reading every connected trackpad; nil where the
    /// framework is absent, no device is connected, or a reader
    /// already runs.
    static func live(deliver: @escaping Deliver) -> TouchReaderHandle? {
        guard MultitouchSupport.isAvailable,
            let register = MultitouchSupport.registerSymbol.function,
            let start = MultitouchSupport.startSymbol.function
        else { return nil }
        let list = MultitouchSupport.devices()
        guard !list.devices.isEmpty else { return nil }
        let reader = TouchReader(deliver: deliver, list: list)
        let claimed = current.withLock { slot -> Bool in
            guard slot == nil else { return false }
            slot = reader
            return true
        }
        guard claimed else { return nil }
        TouchFingerCount.set(0)
        for device in list.devices {
            register(device, frameCallback)
            _ = start(device, 0)
        }
        return reader
    }

    func stop() {
        let ours = Self.current.withLock { slot -> Bool in
            guard slot === self else { return false }
            slot = nil
            return true
        }
        guard ours else { return }
        TouchFingerCount.set(0)
        guard let unregister = MultitouchSupport.unregisterSymbol.function,
            let stop = MultitouchSupport.stopSymbol.function
        else { return }
        for device in list.devices {
            unregister(device, Self.frameCallback)
            _ = stop(device)
        }
    }

    /// The one C entry, on the framework's thread.
    private static let frameCallback: MultitouchSupport.FrameCallback = {
        device,
        touches,
        count,
        time,
        _ in
        guard let reader = current.withLock({ $0 }) else { return 0 }
        reader.receive(
            device: device,
            touches: touches,
            count: Int(count),
            time: time
        )
        return 0
    }

    private func receive(
        device: MultitouchSupport.Device?,
        touches: UnsafeMutableRawPointer?,
        count: Int,
        time: Double
    ) {
        let contacts: [TouchContact]
        if let touches, count > 0 {
            contacts = MultitouchSupport.contacts(
                in: UnsafeRawBufferPointer(
                    start: touches,
                    count: count * MultitouchSupport.Layout.stride
                ),
                count: count
            )
        } else {
            contacts = []
        }
        // A frame in flight past `stop()` leaves the reset standing.
        if Self.current.withLock({ $0 === self }) {
            TouchFingerCount.set(contacts.count)
        }
        let frame = TouchFrame(
            time: time,
            contacts: contacts,
            modifiers: ScrollChord(
                flags: CGEventSource.flagsState(.combinedSessionState)
            )
        )
        let key = UInt(bitPattern: device)
        let events = routers.withLock { routers in
            var router = routers[key] ?? TrackpadGestureRouter()
            let events = router.route(frame)
            routers[key] = router
            return events
        }
        if !events.isEmpty { deliver(events) }
    }
}
