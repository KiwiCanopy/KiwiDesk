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
    private let natural = ScrollGestureField.naturalMouse.rawValue

    private var table: RuleReachTable<ScrollGestureValue> {
        .scrollGestures(
            base: .defaults,
            overrides: [
                ("Home", nil),
                ("Work", ScrollGestureOverride(naturalMouse: .off)),
            ]
        )
    }

    @Test("a profile's override reads as its own value")
    func overrideIsOwn() {
        let t = table
        #expect(t.resolved(natural, for: "Work") == .natural(.off))
        #expect(t.resolved(natural, for: "Home") == .natural(.system))
        #expect(t.reach(of: natural, editing: "Home").isShared)
        #expect(!t.reach(of: natural, editing: "Work").isShared)
        #expect(t.differing(natural, editing: "Home") == ["Work"])
    }

    @Test("a shared value moves the base; an own value is kept")
    func sharedMovesTheBase() {
        var t = table
        t.apply(
            natural,
            value: .natural(.off),
            reach: .shared(joining: []),
            editing: "Home"
        )
        var expected = ScrollGestureBase.defaults
        expected.naturalMouse = .off
        #expect(t.scrollGestureBase(original: .defaults) == expected)
        // Work's own `.off` now equals the base: it follows.
        #expect(
            t.scrollGestureOverride(for: "Work", original: .defaults)
                == nil
        )
    }

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
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
        page.scrollGesture.naturalTrackpad = .off
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        #expect(
            try core.profiles.read(name: "Work").scrollGesture
                == ScrollGestureOverride(
                    naturalTrackpad: .off,
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

}

/// A Lua-owned config's scroll base is what `init.lua` declares
/// NOW: the load resets the inputs and configures once at its
/// tail, so a verb deleted from the file stops holding (#1656).
@Suite("Scroll gesture reload (#1656)", .serialized)
@MainActor
struct ScrollGestureReloadTests {
}
