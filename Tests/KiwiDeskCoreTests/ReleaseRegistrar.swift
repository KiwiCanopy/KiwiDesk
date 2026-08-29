import Foundation

@testable import KiwiDeskCore

/// A registrar fake that can report releases — the channel the
/// hold-to-glide engine arms on (#1056). The press-only fakes
/// across the test trees deliberately do NOT conform, which is
/// the `HotkeyReleaseReporting` split working as designed.
/// Split from `HoldGlideWiringTests` at the file ceiling; that
/// suite is its consumer.
@MainActor
final class ReleaseRegistrar: HotkeyRegistrar,
    HotkeyReleaseReporting
{
    var onRelease: @MainActor (UInt32) -> Void = { _ in }
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var keyCodes: [UInt32: UInt32] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        let id = nextID
        nextID += 1
        handlers[id] = handler
        keyCodes[id] = keyCode
        return id
    }

    func unregister(id: UInt32) {
        handlers[id] = nil
        keyCodes[id] = nil
    }

    func press(keyCode: UInt32) {
        for (id, code) in keyCodes where code == keyCode {
            handlers[id]?()
        }
    }

    /// Mirrors `CarbonHotkeyCenter.dispatchRelease`: a release
    /// for an unregistered id is dropped.
    func release(keyCode: UInt32) {
        for (id, code) in keyCodes where code == keyCode {
            onRelease(id)
        }
    }
}
