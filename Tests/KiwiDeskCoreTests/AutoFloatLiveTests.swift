import AppKit
import Testing

@testable import KiwiDeskCore

/// What a changed guess does to windows already tracked (#2173),
/// what the verb may touch inside a config load, and that every
/// window-rule family a profile carries reaches the resolve.
@Suite("Automatic float escape, live (#2173)", .serialized)
@MainActor
struct AutoFloatLiveTests {
    private final class Box {
        var floats: [Bool] = []
    }

    private static let pid: pid_t = 727_051
    private static let id = WindowID(51)

    private func fixedSizeReading() -> TrackedReading {
        TrackedReading(
            fullscreen: false,
            subrole: kAXStandardWindowSubrole,
            frame: .zero,
            autoReason: .fixedSize,
            traits: nil
        )
    }

    /// A tiled window is never floated by a later fixed-size
    /// reading (#2070) — unless a changed guess forgot its verdict,
    /// which is judged as at adoption.
    @Test("turning the guess back on re-floats a fixed-size window")
    func changedGuessRejudges() {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.activationPolicy = { _ in .regular }
        loop.onEvent = { event in
            if case .windowFloatChanged(_, let on) = event {
                box.floats.append(on)
            }
        }
        loop.elements[Self.pid] = [
            Self.id: AXUIElementCreateApplication(901_051)
        ]
        let app = AppRef(bundleID: nil, name: "Fixed")
        loop.detectedFloating[Self.id] = .tiles
        loop.recheckFloat(
            id: Self.id,
            pid: Self.pid,
            app: app,
            reading: fixedSizeReading()
        )
        #expect(loop.detectedFloating[Self.id] == .tiles)
        #expect(box.floats.isEmpty)
        let off = FloatGuess(enabled: false)
        loop.floatRules = FloatRules([], guess: FloatGuess())
        loop.rejudgeGuesses(from: off)
        #expect(loop.detectedFloating[Self.id] == nil)
        loop.recheckFloat(
            id: Self.id,
            pid: Self.pid,
            app: app,
            reading: fixedSizeReading()
        )
        #expect(loop.detectedFloating[Self.id] == .floats(.fixedSize))
        #expect(box.floats == [true])
    }

    @Test("an unchanged guess forgets nothing")
    func unchangedGuessKeeps() {
        let loop = EventLoop()
        loop.elements[Self.pid] = [
            Self.id: AXUIElementCreateApplication(901_051)
        ]
        loop.detectedFloating[Self.id] = .tiles
        loop.rejudgeGuesses(from: loop.floatRules.guess)
        #expect(loop.detectedFloating[Self.id] == .tiles)
    }

    /// A Dock-less app's window is an overlay — no ring, no bar row
    /// — only while a guess may float it; a raised-layer one stays
    /// an overlay under a Tile rule.
    @Test("a Tile rule clears a Dock-less app's overlay flag")
    func tileRuleClearsOverlay() {
        let core = makeTestCore()
        core.eventLoop.activationPolicy = { _ in .accessory }
        let app = "com.valvesoftware.steam"
        let raised = WindowID(52)
        core.state.windows.upsert(
            ManagedWindow(
                id: Self.id,
                pid: Self.pid,
                appName: "Steam",
                appBundleID: app,
                isTransientOverlay: true,
                subrole: kAXStandardWindowSubrole
            )
        )
        core.state.windows.upsert(
            ManagedWindow(
                id: raised,
                pid: Self.pid,
                appName: "Steam",
                appBundleID: app,
                isTransientOverlay: true,
                isRaisedLayer: true,
                subrole: kAXStandardWindowSubrole
            )
        )
        core.installFloatRules(
            FloatRules([], guess: FloatGuess(tileRules: [app]))
        )
        #expect(core.state.windows[Self.id]?.isTransientOverlay == false)
        #expect(core.state.windows[raised]?.isTransientOverlay == true)
        core.installFloatRules(FloatRules([], guess: FloatGuess()))
        #expect(core.state.windows[Self.id]?.isTransientOverlay == true)
    }

    /// Inside a load the verb writes its base and nothing else: a
    /// resolve there would lay the live profile's rules onto the
    /// bases the load just emptied, and an `init.lua` that declares
    /// no table would capture them as the global base.
    @Test("the verb inside init.lua leaks no profile rule")
    func verbInsideLoadLeaksNothing() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-autofloat-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "KiwiDesk.set_float_automatically(false)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings(),
                appRules: AppRuleOverride(rules: [
                    "com.leak.app": SpaceID("2")
                ]),
                floatRules: RuleListOverride(rules: ["com.leak.float": true])
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        core.loadConfig()
        #expect(core.globalRuleBase.appRules["com.leak.app"] == nil)
        #expect(!core.globalRuleBase.floatRules.contains("com.leak.float"))
        #expect(!core.eventLoop.floatRules.guess.enabled)
    }

    /// The verb writes the base; a profile's own value wins.
    @Test("a profile's override outranks the verb's base")
    func profileOverrideOutranksVerb() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-autofloat-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings(),
                floatAutomatically: true
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        #expect(
            core.execute("set_float_automatically", args: [.bool(false)])
                .isSuccess
        )
        #expect(core.globalRuleBase.floatAutomatically == false)
        #expect(core.eventLoop.floatRules.guess.enabled)
    }

    /// Every window-rule family `Profile` carries reaches the
    /// resolve through `WindowRuleOverrides`. Limitation: a family
    /// is found by its override type's name, and the one plain
    /// value, `floatAutomatically`, is listed by hand.
    @Test("every profile rule family reaches the resolve")
    func ruleFamilyParity() {
        let profile = Profile(
            name: "All",
            monitorSets: [MonitorSet(monitors: [])],
            spaceModes: [:],
            settings: TilingSettings(),
            appRules: AppRuleOverride(rules: ["a": SpaceID("1")]),
            floatRules: RuleListOverride(rules: ["f": true]),
            ignoreRules: RuleListOverride(rules: ["i": true]),
            floatAutomatically: false,
            tileRules: RuleListOverride(rules: ["t": true])
        )
        var families: Set<String> = ["floatAutomatically"]
        for child in Mirror(reflecting: profile).children {
            let type = String(describing: type(of: child.value))
            if type.contains("AppRuleOverride")
                || type.contains("RuleListOverride"),
                let label = child.label
            {
                families.insert(label)
            }
        }
        #expect(families == fieldNames(WindowRuleOverrides()))
        let resolved = fieldValues(WindowRuleOverrides(profile))
        let stored = fieldValues(profile)
        for family in families {
            #expect(resolved[family] == stored[family], "\(family)")
        }
    }
}
