import Foundation

@testable import KiwiDeskCore

/// A `HotkeyRegistrar` that touches no OS state (#565) — the
/// GUI-target twin of the Core test target's fake, for suites
/// that don't assert on registration calls.
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

/// GUI-target twin of `Tests/KiwiDeskCoreTests/TestCore.swift` —
/// test targets cannot see each other, so each carries one copy.
/// `MachineTouchTests` pins the two copies to the same
/// neutralization set, and pins every `KiwiCore(` call in the
/// test trees to these two files, so a new suite cannot
/// re-inherit a live production default by forgetting one
/// argument (#565: the live `CarbonHotkeyCenter` seized the
/// developer's global ⌃⌥ chords; a nil `configDirectory`
/// resolves to the real `~/.config/KiwiDesk`).
///
/// Defaults a test must never inherit, all neutralized here:
/// - `hotkeyRegistrar` — no-op, not the live Carbon center.
/// - `configDirectory` — throwaway temp dir, not `~/.config`.
/// - `reduceMotion` — pinned false, not the host's real
///   `NSWorkspace` Reduce-Motion state.
/// - `windowServerTrackingDisabled` — pinned false, not the
///   host's exported `KIWIDESK_NO_WS_TRACKING` QA lever (#596).
/// - `allScreenBounds` — pinned `[]` (the single-screen
///   verdict), not the host's real screen arrangement (#878).
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
    core.tiler.animation.reduceMotion = { false }
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
    // Same class, fourth time (#878): the per-retile neighbor
    // scan defaults to the real screen list, so on a
    // multi-screen dev Mac an engine fixture would inherit the
    // host's arrangement and wall a scrolling edge that a
    // single-screen CI runner leaves open — the #523 leak, one
    // hook over. Pin the single-screen verdict (no neighbors:
    // every edge open); an adjacency suite injects a fabricated
    // list itself.
    core.tiler.allScreenBounds = { [] }
    // Same class, fifth time (#933): the own-key-window seam
    // defaults to a live `NSApplication.shared` read, so a
    // runner that happens to hold a key window would suppress
    // the focused ring in every border suite. Pin "no own key
    // window"; the stand-down suites inject their own reading.
    core.eventLoop.ownKeyWindow = { nil }
    // Same class, sixth time (#1146): the compositor reads behind
    // the gone classifier and the away ledger default LIVE, and
    // a fixture id can be a real CGWindowID on the host — one
    // hosted on an unshown Desktop would read `vanished`, file
    // the ledger and arm a live census. Pin "no compositor"; a
    // suite that wants a verdict states it on `desktopMemory`.
    core.desktopMemory.readWindowSpace = { _ in .unavailable }
    core.desktopMemory.readCensus = { _ in nil }
    // Same class, seventh time (#1147): the Desktop stamp write
    // defaults LIVE, and a fixture space id is a real Desktop id
    // on the host — Desktop 1 is id 1 — so any suite that boots a
    // core or switches Desktops would stamp the developer's own
    // Desktops through the real bridge. Pin "the write is
    // refused", which is exactly the bridge-absent host; the
    // stamping suite takes the live writer back explicitly, with
    // the bridge itself faked.
    core.desktopMemory.writeStamp = { _, _ in false }
    return core
}
