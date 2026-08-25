import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure lifecycle-reason classifiers (#40).
@Suite("Lifecycle reason classifiers")
struct LifecycleReasonTests {
    @Test("Minimize beats the native-switch window")
    func minimizeWins() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: true,
                sinceDesktopSwitch: 0.1
            ) == .minimized
        )
    }

    @Test("A destroy inside the settle window is vanished")
    func vanishedInWindow() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                sinceDesktopSwitch: 0.5
            ) == .vanished
        )
    }

    @Test("A destroy after the settle window is closed")
    func closedAfterWindow() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                sinceDesktopSwitch: 1.5
            ) == .closed
        )
    }

    @Test("A tracked minimized id restores")
    func restoredWins() {
        #expect(
            WindowAppearReason.classify(
                wasMinimized: true,
                hadRememberedSpace: true
            ) == .restored
        )
    }

    @Test("A remembered space returns")
    func returned() {
        #expect(
            WindowAppearReason.classify(
                wasMinimized: false,
                hadRememberedSpace: true
            ) == .returned
        )
    }

    @Test("Nothing remembered is new")
    func fresh() {
        #expect(
            WindowAppearReason.classify(
                wasMinimized: false,
                hadRememberedSpace: false
            ) == .new
        )
    }
}
