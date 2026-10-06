import CoreGraphics
import Darwin

/// WindowServer's create and destroy notifications for every
/// app's windows (#1877): a WAKE-UP for the AX path, never a
/// source of truth. Codes and payload probed on device
/// 2026-10-06 (macOS 27): 1325 create, 1326 destroy, 12 bytes
/// with the window id at offset 8. The callback reads nothing
/// but the payload: it runs inside the port's drain, which the
/// border pump's flush waits on.
@MainActor
enum SkyLightWindowLifecycle {
    enum Change: UInt32, CaseIterable {
        case created = 1325
        case destroyed = 1326
    }

    private static var sink: (@MainActor (Change, WindowID) -> Void)?

    /// Registers once per process and routes every change to
    /// `sink`; false where WindowServer offers no route, which
    /// leaves the AX notifications and the heal alone.
    static func start(
        sink: @escaping @MainActor (Change, WindowID) -> Void
    ) -> Bool {
        guard let port = SkyLightEventPort.shared else { return false }
        self.sink = sink
        // Every code is tried: a partial route still wakes.
        let registered = Change.allCases.map {
            port.register(code: $0.rawValue, lifecycleNotifyCallback)
        }
        return !registered.contains(false)
    }

    /// Drops the sink; registration has no unregister, so a later
    /// change is heard and discarded.
    static func stop() {
        sink = nil
    }

    /// The window id in a lifecycle payload, nil when short.
    nonisolated static func windowID(
        in data: UnsafeRawPointer?,
        length: Int
    ) -> WindowID? {
        let offset = 8
        guard let data,
            length >= offset + MemoryLayout<CGWindowID>.size
        else { return nil }
        return WindowID(
            data.loadUnaligned(
                fromByteOffset: offset,
                as: CGWindowID.self
            )
        )
    }

    fileprivate static func deliver(_ code: UInt32, _ id: WindowID) {
        guard let change = Change(rawValue: code) else { return }
        sink?(change, id)
    }
}

private let lifecycleNotifyCallback: SkyLightEventPort.NotifyProc = {
    code,
    data,
    length,
    _ in
    // Copy before returning: the payload belongs to the event
    // being drained.
    guard
        let id = SkyLightWindowLifecycle.windowID(
            in: data,
            length: length
        )
    else { return }
    let send: @MainActor @Sendable () -> Void = {
        SkyLightWindowLifecycle.deliver(code, id)
    }
    if pthread_main_np() != 0 {
        MainActor.assumeIsolated { send() }
    } else {
        DispatchQueue.main.async(execute: send)
    }
}
