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

    @Test("A manual override outlives detection verdict flips")
    func overrideBeatsDetectionFlips() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        // A title-rule verdict flip (#160 recheck) must not
        // revert an explicit make_floating.
        state.apply(
            .windowFloatChanged(
                WindowID(1),
                isFloating: false
            )
        )
        #expect(state.windows[WindowID(1)]?.isFloating == true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("Detection verdicts apply to unoverridden windows")
    func detectionAppliesWithoutOverride() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: true)
        )
        #expect(state.windows[WindowID(1)]?.isFloating == true)
    }

    @Test("Detection self-heal clears a stale overlay flag (#300)")
    func selfHealClearsOverlay() {
        var state = StateCoordinator()
        // A window mis-snapshotted at track time as a floating
        // overlay (a one-off bad subrole/layer read).
        var overlay = makeWindow(1, floating: true)
        overlay.isTransientOverlay = true
        state.apply(.windowCreated(overlay))
        #expect(
            state.windows[WindowID(1)]?.isTransientOverlay == true
        )
        // `recheckFloat` corrects it back to a tiled standard
        // window; the overlay flag must clear with the float state
        // so it keeps its focus ring.
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: false)
        )
        #expect(state.windows[WindowID(1)]?.isFloating == false)
        #expect(
            state.windows[WindowID(1)]?.isTransientOverlay == false
        )
    }

    @Test("make_tiled also clears a stale overlay flag (#300)")
    func manualTileClearsOverlay() {
        var state = StateCoordinator()
        var overlay = makeWindow(1, floating: true)
        overlay.isTransientOverlay = true
        state.apply(.windowCreated(overlay))
        // The manual make_tiled path routes through the same
        // `WindowManager.setFloating`, so the invariant holds there
        // too, not just on the detection path.
        state.setFloating(WindowID(1), false)
        #expect(
            state.windows[WindowID(1)]?.isTransientOverlay == false
        )
    }

    @Test("A window that stays floating keeps its overlay flag")
    func stillFloatingKeepsOverlay() {
        var state = StateCoordinator()
        var overlay = makeWindow(1, floating: true)
        overlay.isTransientOverlay = true
        state.apply(.windowCreated(overlay))
        // A verdict that stays floating leaves the flag intact.
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: true)
        )
        #expect(
            state.windows[WindowID(1)]?.isTransientOverlay == true
        )
    }

    @Test("A late-loading title still restores the intent")
    func lazyTitleRestores() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        // Electron/WebKit reopen: tracked before the title
        // arrives, so the create-time identity match misses.
        state.apply(.windowCreated(makeWindow(2, title: "")))
        #expect(state.windows[WindowID(2)]?.isFloating == false)
        state.apply(
            .windowTitleChanged(WindowID(2), "Doc")
        )
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("The remembered identity uses the latest title")
    func renamedTitleRemembers() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, title: "A")))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowTitleChanged(WindowID(1), "B")
        )
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "B")))
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("Empty titles carry no identity to remember")
    func emptyTitleNeverRemembered() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1, title: "")))
        state.setFloating(WindowID(1), true)
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2, title: "")))
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

    @Test("Clearing the override returns detection control")
    func clearRestoresDetection() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(1)))
        state.setFloating(WindowID(1), true)
        state.clearFloatOverride(WindowID(1))
        // Detection verdicts apply again ...
        state.apply(
            .windowFloatChanged(WindowID(1), isFloating: false)
        )
        #expect(state.windows[WindowID(1)]?.isFloating == false)
        // ... and reopen restores nothing (#164).
        state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        state.apply(.windowCreated(makeWindow(2)))
        #expect(state.windows[WindowID(2)]?.isFloating == false)
    }
}

/// The titled-rule gate for the title-change recheck (#160).
@Suite("FloatRules title gate")
struct FloatRulesTitleGateTests {
    @Test("Titled rule for the app gates open")
    func titledRule() {
        let rules = FloatRules(["com.apple.finder:Get Info"])
        #expect(rules.hasTitleRule(bundleID: "com.apple.finder"))
    }

    @Test("App-only rule needs no title recheck")
    func appOnlyRule() {
        let rules = FloatRules(["com.apple.calculator"])
        #expect(
            !rules.hasTitleRule(bundleID: "com.apple.calculator")
        )
    }

    @Test("Other apps stay gated off")
    func otherApp() {
        let rules = FloatRules(["com.apple.finder:Get Info"])
        #expect(!rules.hasTitleRule(bundleID: "com.apple.safari"))
    }
}
