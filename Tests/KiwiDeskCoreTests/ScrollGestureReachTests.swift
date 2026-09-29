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
        #expect(ScrollChordRefusal.of([], other: step) == nil)
        #expect(
            ScrollChordRefusal.of([.control], other: step) == .singleModifier
        )
        #expect(ScrollChordRefusal.of(step, other: step) == .otherGesture)
        #expect(ScrollChordRefusal.of([.control, .shift], other: step) == nil)
    }
}
