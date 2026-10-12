import AppKit
import Testing

@testable import KiwiDeskCore

/// The Tile picker's list (#2071): the apps the guess floated a
/// window of this session, recorded whatever the switch and the
/// Tile rules say, most recent first and capped.
@Suite("Guessed apps (#2071)", .serialized)
@MainActor
struct GuessedAppsTests {
    private static let pid: pid_t = 727_071
    private static let steam = "com.valvesoftware.steam.helper"

    private func reading(_ reason: AutoFloatReason?) -> TrackedReading {
        TrackedReading(
            fullscreen: false,
            subrole: kAXStandardWindowSubrole,
            frame: .zero,
            autoReason: reason,
            traits: nil
        )
    }

    private func loop(
        _ policy: NSApplication.ActivationPolicy
    ) -> EventLoop {
        let loop = EventLoop()
        loop.onLog = { _ in }
        loop.activationPolicy = { _ in policy }
        return loop
    }

    private func recheck(
        _ loop: EventLoop,
        _ reason: AutoFloatReason?,
        app: String = steam
    ) {
        loop.recheckFloat(
            id: WindowID(71),
            pid: Self.pid,
            app: AppRef(bundleID: app, name: "Steam Helper"),
            reading: reading(reason)
        )
    }

    private func apps(_ loop: EventLoop) -> [String] {
        loop.guessedApps.entries.map(\.bundleID)
    }

    @Test("a guessed float files its app; structure and rules do not")
    func guessesFile() {
        let fixed = loop(.regular)
        recheck(fixed, .fixedSize)
        #expect(apps(fixed) == [Self.steam])
        for reason: AutoFloatReason? in [.panel, .rule, nil] {
            let other = loop(.regular)
            recheck(other, reason)
            #expect(apps(other).isEmpty)
        }
    }

    /// A Dock-less app is filed even while its Tile rule or the
    /// switch keeps it tiled, so the picker offers it to another
    /// profile's draft.
    @Test("no Dock icon files the app whatever the escapes")
    func accessoryIgnoresTheEscapes() {
        let ruled = loop(.accessory)
        ruled.floatRules = FloatRules(
            [],
            guess: FloatGuess(tileRules: [Self.steam])
        )
        recheck(ruled, nil)
        #expect(apps(ruled) == [Self.steam])
        let off = loop(.accessory)
        off.floatRules = FloatRules([], guess: FloatGuess(enabled: false))
        recheck(off, nil)
        #expect(apps(off) == [Self.steam])
    }

    /// A fixed size is read only where the live guess asks, so an
    /// escaped regular app's window files nothing (the stated gap).
    @Test("an escaped regular app files nothing")
    func escapedRegularAppIsUnseen() {
        let ruled = loop(.regular)
        ruled.floatRules = FloatRules(
            [],
            guess: FloatGuess(tileRules: [Self.steam])
        )
        recheck(ruled, nil)
        #expect(apps(ruled).isEmpty)
    }

    @Test("a note moves its app first and the cap drops the oldest")
    func recencyAndCap() {
        var guessed = GuessedApps()
        guessed.note(bundleID: "A.App", name: "A")
        guessed.note(bundleID: "b.app", name: "B")
        guessed.note(bundleID: "a.app", name: "A")
        #expect(guessed.entries.map(\.bundleID) == ["a.app", "b.app"])
        for index in 0..<GuessedApps.cap {
            guessed.note(bundleID: "app\(index)", name: "\(index)")
        }
        #expect(guessed.entries.count == GuessedApps.cap)
        #expect(!guessed.entries.contains { $0.bundleID == "b.app" })
        #expect(guessed.entries.first?.bundleID == "app\(GuessedApps.cap - 1)")
    }

    /// Open apps first with their windows' titles, then the
    /// remembered ones, which the cap can never hide while open.
    @Test("the query puts open guesses first, titled")
    func queryOrder() {
        let core = makeTestCore()
        core.eventLoop.guessedApps.note(bundleID: "old.app", name: "Old")
        core.eventLoop.guessedApps.note(bundleID: Self.steam, name: "Helper")
        core.eventLoop.guessedApps.note(bundleID: "gone.app", name: "Gone")
        let id = WindowID(7_101)
        core.state.windows.upsert(
            ManagedWindow(
                id: id,
                pid: Self.pid,
                appName: "Steam Helper",
                appBundleID: Self.steam,
                title: "Steam"
            )
        )
        core.eventLoop.detectedFloating[id] = .floats(.accessoryApp)
        let apps = core.guessedFloatApps()
        #expect(apps.map(\.bundleID) == [Self.steam, "gone.app", "old.app"])
        #expect(apps.first?.titles == ["Steam"])
        #expect(apps.dropFirst().allSatisfy { $0.titles.isEmpty })
        core.eventLoop.detectedFloating[id] = .floats(.panel)
        #expect(core.guessedFloatApps().first?.bundleID == "gone.app")
    }

    /// The cap drops only the store's record: a window still
    /// floating on a guess lists its app whatever the store holds.
    @Test("an open guess the store no longer holds is still listed")
    func openGuessOutlivesTheCap() {
        let core = makeTestCore()
        let id = WindowID(7_102)
        core.state.windows.upsert(
            ManagedWindow(
                id: id,
                pid: Self.pid,
                appName: "Steam Helper",
                appBundleID: Self.steam,
                title: "Steam"
            )
        )
        core.eventLoop.detectedFloating[id] = .floats(.fixedSize)
        let kept = WindowID(7_103)
        core.state.windows.upsert(
            ManagedWindow(
                id: kept,
                pid: Self.pid + 1,
                appName: "Kept",
                appBundleID: "kept.app",
                title: "Prefs"
            )
        )
        core.eventLoop.detectedFloating[kept] = .floats(.fixedSize)
        core.eventLoop.guessedApps.note(bundleID: "kept.app", name: "Kept")
        let apps = core.guessedFloatApps()
        // The recorded open app leads; the evicted one follows it.
        #expect(apps.map(\.bundleID) == ["kept.app", Self.steam])
        #expect(apps.last?.name == "Steam Helper")
        #expect(apps.last?.titles == ["Steam"])
    }
}
