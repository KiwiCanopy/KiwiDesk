import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// KiwiDesk's marked own window — Settings — is titled after the
/// area it shows (#2059), so its reopen identity is the mark, never
/// the title: a remembered float or sticky follows the window
/// whatever area it closed and reopened on, and an area change
/// never re-triggers one.
@Suite("Own window reopen identity (#2059)")
struct OwnWindowIdentityTests {
    private func settings(
        _ id: UInt32,
        title: String,
        marked: Bool = true
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 4242,
            appName: "KiwiDesk",
            title: title,
            carriesOwnMark: marked
        )
    }

    private func close(_ id: UInt32, in state: inout StateCoordinator) {
        state.apply(
            .windowDestroyed(WindowID(id), wasMinimized: false)
        )
    }

    @Test("A float closed on one area reopens floated on Home")
    func floatSurvivesAnAreaChange() {
        var state = StateCoordinator()
        state.apply(.windowCreated(settings(1, title: "Shortcuts")))
        state.setFloating(WindowID(1), true)
        close(1, in: &state)
        state.apply(.windowCreated(settings(2, title: "Settings")))
        #expect(state.windows[WindowID(2)]?.isFloating == true)
    }

    @Test("A sticky closed on one area reopens sticky on Home")
    func stickySurvivesAnAreaChange() {
        var state = StateCoordinator()
        state.apply(.windowCreated(settings(1, title: "General")))
        state.setSticky(WindowID(1), .global)
        close(1, in: &state)
        state.apply(.windowCreated(settings(2, title: "Settings")))
        #expect(state.windows[WindowID(2)]?.stickyScope == .global)
    }

    @Test("Navigating areas never re-triggers a float")
    func areaChangesNeverRetrigger() {
        var state = StateCoordinator()
        state.apply(.windowCreated(settings(1, title: "Shortcuts")))
        state.setFloating(WindowID(1), true)
        close(1, in: &state)
        state.apply(.windowCreated(settings(2, title: "Settings")))
        // The user tiles the reopened window, then navigates back
        // to the area it closed on.
        state.setFloating(WindowID(2), false)
        for title in ["Shortcuts", "General", "Settings"] {
            state.apply(.windowTitleChanged(WindowID(2), title))
            #expect(state.windows[WindowID(2)]?.isFloating == false)
        }
    }

    @Test("Navigating areas on a tiled window floats nothing")
    func tiledWindowStaysTiled() {
        var state = StateCoordinator()
        state.apply(.windowCreated(settings(1, title: "Settings")))
        for title in ["Shortcuts", "Profiles", "Settings"] {
            state.apply(.windowTitleChanged(WindowID(1), title))
            #expect(state.windows[WindowID(1)]?.isFloating == false)
        }
    }

    /// The control: an unmarked window keeps the title-keyed
    /// identity, so a drifted title still misses (#160).
    @Test("An unmarked window keeps its title identity")
    func unmarkedWindowKeysOnTitle() {
        var state = StateCoordinator()
        state.apply(
            .windowCreated(settings(1, title: "A", marked: false))
        )
        state.setFloating(WindowID(1), true)
        close(1, in: &state)
        state.apply(
            .windowCreated(settings(2, title: "B", marked: false))
        )
        #expect(state.windows[WindowID(2)]?.isFloating == false)
    }

    @Test("The mark carries through a re-key")
    func markSurvivesRekey() {
        let window = settings(1, title: "Settings")
        #expect(window.withID(WindowID(9)).carriesOwnMark)
    }
}
