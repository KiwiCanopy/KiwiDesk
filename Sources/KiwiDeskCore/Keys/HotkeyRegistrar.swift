import Foundation

/// Abstraction over Carbon hotkey registration for test
/// isolation. An implementor never fires the handler of a FAILED
/// registration — the hold-to-glide press path leans on it
/// (`RegistrationBox` carries a nil id for exactly that handler).
@MainActor
public protocol HotkeyRegistrar: AnyObject {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32?
    func unregister(id: UInt32)
}

extension CarbonHotkeyCenter: HotkeyRegistrar {}
