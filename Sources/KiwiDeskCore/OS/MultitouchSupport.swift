import CoreFoundation
import Foundation

/// The private MultitouchSupport framework, resolved by `dlsym`
/// (#1873). It reads raw trackpad fingers system-wide with no
/// permission at all (probed 2026-10-31 on macOS 27, recorded on
/// the issue). Its fallback is absence: a failed lookup leaves
/// every touch slot without a reader, and the scroll gestures keep
/// working through their own public tap.
enum MultitouchSupport {
    /// An `MTDeviceRef`, a CF object the framework owns.
    typealias Device = UnsafeMutableRawPointer
    /// `int (*)(MTDeviceRef, MTTouch *, int, double, int)`.
    typealias FrameCallback =
        @convention(c) (
            Device?, UnsafeMutableRawPointer?, Int32, Double, Int32
        ) -> Int32

    typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    typealias RegisterFn =
        @convention(c) (Device, FrameCallback) -> Void
    typealias StartFn = @convention(c) (Device, Int32) -> Int32
    typealias StopFn = @convention(c) (Device) -> Int32

    private nonisolated(unsafe) static let handle: UnsafeMutableRawPointer? =
        dlopen(
            "/System/Library/PrivateFrameworks/"
                + "MultitouchSupport.framework/MultitouchSupport",
            RTLD_LAZY
        )

    static func symbol<T>(
        _ name: String,
        as type: T.Type
    ) -> PrivateSymbol<T> {
        guard let handle, let sym = dlsym(handle, name) else {
            return PrivateSymbol(name: name, function: nil)
        }
        return PrivateSymbol(
            name: name,
            function: unsafeBitCast(sym, to: T.self)
        )
    }

    static let createListSymbol = symbol(
        "MTDeviceCreateList",
        as: CreateListFn.self
    )
    static let registerSymbol = symbol(
        "MTRegisterContactFrameCallback",
        as: RegisterFn.self
    )
    static let unregisterSymbol = symbol(
        "MTUnregisterContactFrameCallback",
        as: RegisterFn.self
    )
    static let startSymbol = symbol("MTDeviceStart", as: StartFn.self)
    static let stopSymbol = symbol("MTDeviceStop", as: StopFn.self)

    /// Whether every symbol the reader calls resolved — the
    /// capability a gesture surface gates on.
    static var isAvailable: Bool {
        createListSymbol.function != nil
            && registerSymbol.function != nil
            && unregisterSymbol.function != nil
            && startSymbol.function != nil
            && stopSymbol.function != nil
    }

    /// The multitouch devices connected now, held by the list
    /// that owns them: a device outlives the list only while the
    /// list is kept.
    struct DeviceList: @unchecked Sendable {
        let list: CFArray?
        let devices: [Device]

        static let empty = DeviceList(list: nil, devices: [])
    }

    /// Every connected device; empty when the framework is absent.
    static func devices() -> DeviceList {
        guard let create = createListSymbol.function,
            let list = create()?.takeRetainedValue()
        else { return .empty }
        let devices = (0..<CFArrayGetCount(list)).compactMap {
            CFArrayGetValueAtIndex(list, $0).map {
                UnsafeMutableRawPointer(mutating: $0)
            }
        }
        return DeviceList(list: list, devices: devices)
    }

    /// The `self_test` rows (#1889): the device list is called,
    /// with nothing to check it against, so it reports `answered`;
    /// the rest register or start a device and are only looked up.
    @MainActor
    static func selfTestProbes() -> [PrivatePathProbe] {
        let home = "MultitouchSupport"
        return [
            .read(createListSymbol.resolution, home: home) {
                .answered("\(devices().devices.count) devices")
            },
            .write(registerSymbol.resolution, home: home),
            .write(unregisterSymbol.resolution, home: home),
            .write(startSymbol.resolution, home: home),
            .write(stopSymbol.resolution, home: home),
        ]
    }
}
