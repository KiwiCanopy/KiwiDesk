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
/// registration, defaulting the two production initializer values
/// a test must never inherit (#565):
///
/// - `hotkeyRegistrar` defaults to a no-op, not the live
///   `CarbonHotkeyCenter` that would seize the user's global
///   chords for the whole run.
/// - `configDirectory` defaults to a throwaway temp dir, not
///   `nil` — which `KiwiCore.init` resolves to the real
///   `~/.config/KiwiDesk` (live socket, profiles, `init.lua`).
///
/// Both are defaults production cannot carry, and both bite the
/// same way: one forgotten argument. Call this instead of the raw
/// initializer. Pass either argument to opt out — a persistence
/// suite that reloads a second core over the same dir passes an
/// explicit `configDirectory`; a registration suite passes a
/// real/fake `hotkeyRegistrar`.
///
/// Shared rather than per-file (a `.claude/rules/tests.md`
/// exception) because it is a stateless primitive with no
/// assertions of its own and no setup/teardown coupling, and
/// because a per-file copy would leave every new suite one
/// forgotten argument away from re-seizing the OS chords — the
/// exact failure #565 removes.
@MainActor
func makeTestCore(
    configDirectory: URL? = nil,
    hotkeyRegistrar: HotkeyRegistrar = NoopHotkeyRegistrar()
) -> KiwiCore {
    let directory =
        configDirectory
        ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwi-test-\(UUID().uuidString)"
        )
    let core = KiwiCore(
        configDirectory: directory,
        hotkeyRegistrar: hotkeyRegistrar
    )
    // Bootstrap wires the real NSWorkspace Reduce-Motion read;
    // neutralize it so a dev machine with Reduce Motion on can't
    // silently turn a KiwiCore test's animations into instant
    // snaps (same host-state-leak class as the hotkey registrar).
    core.tiler.animation.reduceMotion = { false }
    // Same class again (#596): bootstrap reads the
    // `KIWIDESK_NO_WS_TRACKING` QA lever from the real process
    // environment, so a developer who has it exported would get a
    // different core in every test. Inert today — the private
    // runtime never starts under test, so `skyLightActive` is
    // already false — but neutralized here so it stays that way
    // if the lever ever gains a second effect.
    core.borders.windowServerTrackingDisabled = false
    // Same class, third time (#673): `openOrFocus`'s four seams
    // default LIVE, and unlike the two above their touch fires on
    // COMMAND EXECUTION, not on init — so a suite that executes
    // `pull_or_spawn` inherits a real `NSWorkspace` lookup, a real
    // `activate()` and a real app launch without naming any of
    // them. That already shipped once: a command-path test brought
    // the real Finder forward on every run. Making "no app is
    // running" the default means the safe state is what a suite
    // gets by forgetting; a test that wants the branch states a
    // pid itself.
    core.openOrFocus.runningAppPID = { _ in nil }
    core.openOrFocus.openApp = { _, _ in false }
    return core
}
