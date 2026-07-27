import Foundation

@testable import KiwiDeskCore

/// A `HotkeyRegistrar` that touches no OS state (#565).
///
/// It hands back a fresh id for every `register` and forgets it on
/// `unregister`, so `KeybindingManager.activate` sees success
/// without calling the real `RegisterEventHotKey`. The live
/// `CarbonHotkeyCenter` is what a bare `KiwiCore()` gets in
/// production, and it grabs the developer's global chords (the
/// seeded Control-Option arrow/digit tiers) for the whole run —
/// so every suite that is not *about* registration routes through
/// this instead.
final class NoopHotkeyRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}

/// Build a `KiwiCore` for a suite that does not test hotkey
/// registration, with the registrar defaulted to a no-op (#565).
///
/// This is the test-side default the production `KiwiCore.init`
/// cannot be: its registrar defaults to the live
/// `CarbonHotkeyCenter`, so a suite that omits the argument would
/// silently seize the user's global shortcuts and fight a running
/// KiwiDesk over the same chords. Call this instead of the raw
/// initializer; pass `hotkeyRegistrar:` to opt into a real or fake
/// one.
///
/// Shared rather than per-file (a `.claude/rules/tests.md`
/// exception) because it is a stateless primitive with no
/// assertions of its own and no setup/teardown coupling — the same
/// bar the four ratified helpers clear — and because a per-file
/// copy would leave every new suite one forgotten argument away
/// from re-seizing the OS chords, the exact failure #565 removes.
@MainActor
func makeTestCore(
    configDirectory: URL? = nil,
    hotkeyRegistrar: HotkeyRegistrar = NoopHotkeyRegistrar()
) -> KiwiCore {
    KiwiCore(
        configDirectory: configDirectory,
        hotkeyRegistrar: hotkeyRegistrar
    )
}
