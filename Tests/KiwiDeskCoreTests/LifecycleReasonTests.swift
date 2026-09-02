import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure lifecycle-reason classifiers (#40), deciding from
/// the compositor's word since #1146 and from the settle timer
/// only where no compositor can answer.
@Suite("Lifecycle reason classifiers")
struct LifecycleReasonTests {
    @Test("Minimize beats every presence")
    func minimizeWins() {
        for presence in [
            GonePresence.unknown(sinceDesktopSwitch: 0.1),
            .gone,
            .hosted(space: 4, shown: false),
            .hosted(space: 1, shown: true),
        ] {
            #expect(
                WindowGoneReason.classify(
                    wasMinimized: true,
                    presence: presence
                ) == .minimized
            )
        }
    }

    @Test("Hosted on a Desktop nobody shows is vanished")
    func hostedAwayIsVanished() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .hosted(space: 4, shown: false)
            ) == .vanished
        )
    }

    @Test("Hosted nowhere is closed")
    func goneIsClosed() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .gone
            ) == .closed
        )
    }

    @Test("Hosted on a shown Desktop is closed")
    func hostedShownIsClosed() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .hosted(space: 1, shown: true)
            ) == .closed
        )
    }

    @Test("Without a compositor, a destroy inside the settle is vanished")
    func unknownInsideWindowIsVanished() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .unknown(sinceDesktopSwitch: 0.5)
            ) == .vanished
        )
    }

    @Test("Without a compositor, a destroy after the settle is closed")
    func unknownAfterWindowIsClosed() {
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .unknown(sinceDesktopSwitch: 1.5)
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
