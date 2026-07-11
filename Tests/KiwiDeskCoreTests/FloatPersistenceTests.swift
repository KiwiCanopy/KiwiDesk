import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func makeWindow(
    _ id: UInt32,
    pid: pid_t = 100,
    app: String = "TestApp",
    title: String = "Doc",
    floating: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: pid,
        appName: app,
        title: title,
        isFloating: floating
    )
}

/// Manual float intent surviving close/reopen cycles (#160).
@Suite("Float persistence")
struct FloatPersistenceTests {
    @Test("make_floating survives close and reopen")
    func manualFloatSurvivesReopen() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        // Reopened: the OS handed out a new WindowID and
        // detection classified it tiled again.
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("make_tiled survives close and reopen")
    func manualTileSurvivesReopen() {
        var state = StateCoordinator()
        state.apply(
            .windowCreated(makeWindow(1, floating: true))
        )
        state.setFloating(WindowID(1), false)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(
            .windowCreated(makeWindow(2, floating: true))
        )
        #expect(state.windows[WindowID(2)]?.isFloating == false)
    }

    @Test("A drifted title keeps the detection verdict")
    func titleDriftMisses() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, title: "A")))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "B")))
        #expect(state.windows[WindowID(2)]?.isFloating == false)
    }

    @Test("Minimize keeps the float intent for deminiaturize")
    func minimizeKeepsIntent() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: true)
        )
        // Deminiaturize re-tracks under the same WindowID with
        // a fresh (tiled) detection verdict.
        state.apply(.windowCreated(makeWindow(1)))
        #expect(state.windows[WindowID(1)]?.isFloating == true)
    }

    @Test("App termination remembers overrides for relaunch")
    func appTerminationRemembers() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(.appTerminated(pid: 100))
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("A changed detection verdict drops the override")
    func detectionChangeDropsOverride() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowFloatChanged(
                WindowID(1),
                isFloating: false
            )
        )
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isFloating == false)
    }

    @Test("The restored override re-arms for the next cycle")
    func restoredOverrideRearms() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(3)))
        #expect(state.windows[WindowID(3)]?.isFloating == true)
    }

    @Test("Untracked ids never record an override")
    func untrackedIdIgnored() {
        var state = StateCoordinator()
        state.setFloating(WindowID(9), true)
        state.apply(.windowCreated(makeWindow(9)))
        #expect(state.windows[WindowID(9)]?.isFloating == false)
    }
}

/// The titled-rule gate for the title-change recheck (#160).
@Suite("FloatRules title gate")
struct FloatRulesTitleGateTests {
    @Test("Titled rule for the app gates open")
    func titledRule() {
        let rules = FloatRules(["Finder:Get Info"])
        #expect(rules.hasTitleRule(app: "Finder"))
    }

    @Test("App-only rule needs no title recheck")
    func appOnlyRule() {
        let rules = FloatRules(["Calculator"])
        #expect(!rules.hasTitleRule(app: "Calculator"))
    }

    @Test("Other apps stay gated off")
    func otherApp() {
        let rules = FloatRules(["Finder:Get Info"])
        #expect(!rules.hasTitleRule(app: "Safari"))
    }
}
