import Foundation
import Testing

@testable import KiwiDeskCore

/// The scroll gestures as an "Applies to" family (#1656): a row is
/// one field, the base holds every field, and a save writes only
/// the files a change reached — the base to `gui.json`, a profile's
/// divergence to its sparse `scroll_gesture` override.
@Suite("Scroll gesture reach (#1656)", .serialized)
@MainActor
struct ScrollGestureReachTests {
    private let pan = ScrollGestureField.pan.rawValue
    private let natural = ScrollGestureField.naturalMouse.rawValue

    private var table: RuleReachTable<ScrollGestureValue> {
        .scrollGestures(
            base: .defaults,
            overrides: [
                ("Home", nil),
                ("Work", ScrollGestureOverride(naturalMouse: false)),
            ]
        )
    }

    @Test("a profile's override reads as its own value")
    func overrideIsOwn() {
        let t = table
        #expect(t.resolved(natural, for: "Work") == .flag(false))
        #expect(t.resolved(natural, for: "Home") == .flag(true))
        #expect(t.reach(of: natural, editing: "Home").isShared)
        #expect(!t.reach(of: natural, editing: "Work").isShared)
        #expect(t.differing(natural, editing: "Home") == ["Work"])
    }

    @Test("a listed value is the profile's override; the base stays")
    func listedWritesTheOverride() {
        var t = table
        t.apply(
            pan,
            value: .chord([.command, .option]),
            reach: .listed(["Home"]),
            editing: "Home"
        )
        #expect(t.baseTouched.isEmpty)
        #expect(t.scrollGestureBase(original: .defaults) == .defaults)
        #expect(
            t.scrollGestureOverride(for: "Home", original: .defaults)
                == ScrollGestureOverride(pan: [.command, .option])
        )
        #expect(
            t.scrollGestureOverride(for: "Work", original: .defaults)
                == ScrollGestureOverride(naturalMouse: false)
        )
    }

    @Test("a shared value moves the base; an own value is kept")
    func sharedMovesTheBase() {
        var t = table
        t.apply(
            natural,
            value: .flag(false),
            reach: .shared(joining: []),
            editing: "Home"
        )
        var expected = ScrollGestureBase.defaults
        expected.naturalMouse = false
        #expect(t.scrollGestureBase(original: .defaults) == expected)
        // Work's own `false` now equals the base: it follows.
        #expect(
            t.scrollGestureOverride(for: "Work", original: .defaults)
                == nil
        )
    }

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-scroll-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for name in ["Home", "Work"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        return core
    }

    @Test("a save writes the reached profile and leaves the other")
    func saveWritesReachedFiles() throws {
        let core = try makeCore()
        let homeBefore = try Data(
            contentsOf: core.profiles.fileURL(name: "Home")
        )
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.scrollGestures.apply(
            pan,
            value: .chord([.command, .option]),
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(snapshot.isEdited)
        try core.saveRuleReach(snapshot)
        let work = try core.profiles.read(name: "Work")
        #expect(
            work.scrollGesture
                == ScrollGestureOverride(pan: [.command, .option])
        )
        #expect(core.guiConfigStore.load()?.scrollGesture == .defaults)
        #expect(
            try Data(contentsOf: core.profiles.fileURL(name: "Home"))
                == homeBefore
        )
    }

    @Test("a shared save writes gui.json and re-resolves the tap")
    func sharedSaveWritesTheBase() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.scrollGestures.apply(
            ScrollGestureField.longSwipes.rawValue,
            value: .flag(true),
            reach: .shared(joining: []),
            editing: "Home"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.guiConfigStore.load()?.scrollGesture.longSwipes == true)
        #expect(core.mouse.scroll.resolved.longSwipes)
    }

    @Test("a stored page resolves the override and diffs it back")
    func storedPageRoundTrips() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.scrollGesture = ScrollGestureOverride(stepDistance: 90)
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        #expect(page.scrollGesture.stepDistance == 90)
        page.scrollGesture.naturalTrackpad = false
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        #expect(
            try core.profiles.read(name: "Work").scrollGesture
                == ScrollGestureOverride(
                    naturalTrackpad: false,
                    stepDistance: 90
                )
        )
    }

    @Test("a checklist-owned save keeps the stored override")
    func checklistSaveKeepsTheOverride() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.scrollGesture = ScrollGestureOverride(stepDistance: 90)
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        page.scrollGesture.stepDistance = 200
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: false
        )
        #expect(
            try core.profiles.read(name: "Work").scrollGesture
                == ScrollGestureOverride(stepDistance: 90)
        )
    }

    @Test("refusals: one modifier alone, and the other gesture's chord")
    func refusals() {
        let step: ScrollChord = [.control, .option, .command]
        func of(_ chord: ScrollChord) -> ScrollChordRefusal? {
            ScrollChordRefusal.of(chord, other: step, heldBy: .step)
        }
        #expect(of([]) == nil)
        #expect(of([.control]) == .singleModifier)
        #expect(of(step) == .otherGesture(.step))
        #expect(of([.control, .shift]) == nil)
    }

    /// A hand-edited file can reach what the recorder refuses:
    /// the resolve turns a lone modifier off, keeps a shared
    /// chord the pan's, and clamps the distance.
    @Test("the resolve sanitises what a file hands it")
    func resolveSanitises() {
        let core = makeTestCore()
        core.mouse.scroll.onLog = { _ in }
        core.onLog = { _ in }
        var base = ScrollGestureBase.defaults
        base.pan = [.control]
        base.stepDistance = 1
        core.applyScrollGestures(base: base, profile: nil)
        #expect(core.mouse.scroll.resolved.pan.isEmpty)
        let range = ScrollGestureBase.stepDistanceRange
        #expect(core.mouse.scroll.resolved.stepDistance == range.lowerBound)
        base.stepDistance = range.upperBound * 5
        core.applyScrollGestures(base: base, profile: nil)
        #expect(core.mouse.scroll.resolved.stepDistance == range.upperBound)
        base.stepDistance = 1
        base.pan = [.control, .option]
        base.spaceStep = [.control, .option]
        core.applyScrollGestures(base: base, profile: nil)
        #expect(core.mouse.scroll.resolved.pan == [.control, .option])
        #expect(core.mouse.scroll.resolved.spaceStep.isEmpty)
    }

    /// The verb writes the base while the live profile resolves
    /// over it, so a chord clashing with either is refused.
    @Test("a verb's chord clears the other in base and profile")
    func verbChecksBaseAndProfile() {
        let core = makeTestCore()
        core.applyScrollGestures(
            base: .defaults,
            profile: ScrollGestureOverride(pan: [.command, .shift])
        )
        let clash = core.execute(
            "scroll_gesture.set_space_step",
            args: [.string("control+option")]
        )
        #expect(!clash.isSuccess)
        #expect(
            core.mouse.scroll.base.spaceStep == [.control, .option, .command]
        )
        // The mirror: the profile's own pan clashes, the base's
        // does not.
        #expect(
            !core.execute(
                "scroll_gesture.set_space_step",
                args: [.string("command+shift")]
            ).isSuccess
        )
    }
}

/// A Lua-owned config's scroll base is what `init.lua` declares
/// NOW: the load resets the inputs and configures once at its
/// tail, so a verb deleted from the file stops holding (#1656).
@Suite("Scroll gesture reload (#1656)", .serialized)
@MainActor
struct ScrollGestureReloadTests {
    @Test("a reload drops a verb the file no longer declares")
    func reloadDropsARemovedVerb() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-reload-\(UUID().uuidString)")
        )
        core.onLog = { _ in }
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "scroll_gesture.set_pan(\"command+shift\")\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.mouse.scroll.resolved.pan == [.command, .shift])
        #expect(core.mouse.scroll.settings.chords[.pan] == [.command, .shift])
        try "-- nothing\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.mouse.scroll.resolved.pan == [.control, .option])
        #expect(
            core.mouse.scroll.settings.chords[.pan] == [.control, .option]
        )
    }
}
