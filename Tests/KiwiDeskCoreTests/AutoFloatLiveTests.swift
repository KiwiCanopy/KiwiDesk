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
        var log: [String] = []
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
    /// — only while a guess floats it; a dialog or panel stays one,
    /// and an own window's overlay is its structure (#300, #315).
    @Test("the overlay flag follows the verdict's reason")
    func overlayFollowsTheReason() {
        func overlay(_ reason: AutoFloatReason?, own: Bool = false) -> Bool {
            EventLoop.isOverlay(
                FloatVerdict(reason),
                ownProcess: own,
                structural: false
            )
        }
        #expect(overlay(.accessoryApp))
        #expect(overlay(.panel))
        #expect(!overlay(.rule))
        #expect(!overlay(.fixedSize))
        #expect(!overlay(nil))
        #expect(!overlay(.panel, own: true))
        #expect(
            EventLoop.isOverlay(
                .tiles,
                ownProcess: true,
                structural: true
            )
        )
    }

    /// A Tile rule tiles a Dock-less app's window and ends its
    /// overlay in the same recheck; the guess back on restores both.
    @Test("a recheck under a Tile rule ends the overlay")
    func recheckEndsTheOverlay() {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.activationPolicy = { _ in .accessory }
        loop.onEvent = { event in
            switch event {
            case .windowFloatChanged(_, let on): box.log.append("float \(on)")
            case .windowOverlayChanged(_, let on):
                box.log.append("overlay \(on)")
            default: break
            }
        }
        let app = AppRef(bundleID: "com.valvesoftware.steam", name: "Steam")
        let tiled = TrackedReading(
            fullscreen: false,
            subrole: kAXStandardWindowSubrole,
            frame: .zero,
            autoReason: nil,
            traits: nil
        )
        loop.detectedFloating[Self.id] = .floats(.accessoryApp)
        loop.floatRules = FloatRules(
            [],
            guess: FloatGuess(tileRules: ["com.valvesoftware.steam"])
        )
        loop.recheckFloat(id: Self.id, pid: Self.pid, app: app, reading: tiled)
        #expect(box.log == ["float false", "overlay false"])
        box.log = []
        loop.floatRules = FloatRules([], guess: FloatGuess())
        loop.recheckFloat(id: Self.id, pid: Self.pid, app: app, reading: tiled)
        #expect(box.log == ["float true", "overlay true"])
    }

    /// The event lands in state, and the retile it earns redraws
    /// the ring and bar rows the flag gates.
    @Test("the overlay event folds into state")
    func overlayEventFolds() {
        var state = StateCoordinator()
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.id,
                    pid: Self.pid,
                    appName: "Steam",
                    isFloating: true,
                    isTransientOverlay: true
                )
            )
        )
        state.apply(.windowOverlayChanged(Self.id, isOverlay: false))
        #expect(state.windows[Self.id]?.isTransientOverlay == false)
        state.apply(.windowOverlayChanged(Self.id, isOverlay: true))
        #expect(state.windows[Self.id]?.isTransientOverlay == true)
        #expect(
            TilingEngine.shouldRetile(
                after: .windowOverlayChanged(Self.id, isOverlay: true)
            )
        )
    }

    /// An own window's overlay is its structure, fixed at track: a
    /// recheck of one never moves it.
    @Test("an own window's recheck emits no overlay change")
    func ownWindowKeepsItsOverlay() {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.ownWindowIdentifier = { _ in nil }
        loop.onEvent = { event in
            if case .windowOverlayChanged = event { box.log.append("overlay") }
        }
        loop.detectedFloating[Self.id] = .tiles
        loop.recheckFloat(
            id: Self.id,
            pid: getpid(),
            app: AppRef(bundleID: nil, name: "KiwiDesk"),
            reading: TrackedReading(
                fullscreen: false,
                subrole: kAXDialogSubrole,
                frame: .zero,
                autoReason: .panel,
                traits: nil
            )
        )
        #expect(loop.detectedFloating[Self.id] == .floats(.panel))
        #expect(box.log.isEmpty)
    }

    /// The door forgets the verdicts a changed guess reaches, and
    /// none an unchanged one does.
    @Test("installing a changed guess forgets the verdicts it reaches")
    func installRejudges() {
        let core = makeTestCore()
        core.eventLoop.elements[Self.pid] = [
            Self.id: AXUIElementCreateApplication(901_051)
        ]
        core.eventLoop.detectedFloating[Self.id] = .tiles
        core.installFloatRules(FloatRules([], guess: FloatGuess()))
        #expect(core.eventLoop.detectedFloating[Self.id] == .tiles)
        core.installFloatRules(
            FloatRules([], guess: FloatGuess(enabled: false))
        )
        #expect(core.eventLoop.detectedFloating[Self.id] == nil)
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
