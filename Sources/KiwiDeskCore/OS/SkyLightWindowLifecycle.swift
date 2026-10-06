import CoreGraphics
import Darwin

fileprivate typealias LifecycleNotifyProc =
    @convention(c) (
        UInt32,
        UnsafeMutableRawPointer?,
        Int,
        UnsafeMutableRawPointer?
    ) -> Void

/// WindowServer's create and destroy notifications for every
/// app's windows (#1877): a WAKE-UP for the AX path, never a
/// source of truth. Codes and payload probed on device
/// 2026-10-06 (macOS 27): 1325 create, 1326 destroy, 12 bytes
/// with the window id at offset 8. Nil without the symbol or the
/// event port, and the AX notifications plus the heal sweep
/// carry on alone.
@MainActor
final class SkyLightWindowLifecycle {
    enum Change: UInt32, CaseIterable {
        case created = 1325
        case destroyed = 1326
    }

    fileprivate typealias RegisterNotifyFn =
        @convention(c) (
            LifecycleNotifyProc?, UInt32, UnsafeMutableRawPointer?
        ) -> CGError

    private static let registerNotify: RegisterNotifyFn? =
        SkyLight.symbol(
            "SLSRegisterNotifyProc",
            as: RegisterNotifyFn.self
        )

    /// Where a change goes; registration has no unregister, so
    /// the sink is replaced rather than torn down.
    static var sink: (@MainActor (Change, WindowID) -> Void)?

    private static var registered = false

    /// Registers once per process; false where WindowServer
    /// offers no route.
    static func start() -> Bool {
        if registered { return true }
        guard SkyLightEventPort.shared != nil,
            let registerNotify
        else { return false }
        for change in Change.allCases {
            guard
                registerNotify(
                    lifecycleNotifyCallback,
                    change.rawValue,
                    nil
                ) == .success
            else { return false }
        }
        registered = true
        return true
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
            data.loadUnaligned(fromByteOffset: offset, as: CGWindowID.self)
        )
    }

    fileprivate static func deliver(_ code: UInt32, _ id: WindowID) {
        guard let change = Change(rawValue: code) else { return }
        sink?(change, id)
    }
}

private let lifecycleNotifyCallback: LifecycleNotifyProc = {
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
