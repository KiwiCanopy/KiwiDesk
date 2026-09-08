import Foundation
import Testing

@testable import KiwiDeskCore

/// Both switching arms report `switched` (#1336). The silence it
/// replaces was measured: `move_to_desktop_and_follow <current>`
/// printed nothing, logged nothing and exited 0.
///
/// No bridge fakes on purpose — the stand-down returns before
/// `switchDesktop` reaches the bridge.
@Suite("A shown Desktop says so (#1336)", .serialized)
@MainActor
struct DesktopAlreadyShownTests {
    /// A target whose Desktop is the one its screen shows, so
    /// `isCurrent` is true by derivation rather than by hand.
    private func shownTarget() -> KiwiCore.DesktopTarget {
        KiwiCore.DesktopTarget(
            space: 10,
            displayIdentifier: "UUID-A",
            originSpace: 10,
            spaces: authorityTopology(
                mainCurrent: 10,
                secondaryCurrent: 20
            )
        )
    }

    private func pinTopology() {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
    }

    @Test("The stand-down reports switched: false, and says why")
    func standDownReportsNoSwitch() {
        pinTopology()
        defer { resetAuthorityOverrides() }
        let core = makeTestCore()

        let outcome = core.switchDesktop(
            to: shownTarget(),
            verb: "focus_desktop"
        )
        guard case .alreadyShown = outcome else {
            Issue.record("expected .alreadyShown, got \(outcome)")
            return
        }
        let response = outcome.response
        // Still a success: an ensure-shown caller keeps working.
        #expect(response.isSuccess)
        #expect(response.error == nil)
        #expect(
            SwitchOutcomeReading.switched(response) == false
        )
        // An EMPTY note satisfies "carries a note" while shipping
        // the silence #1336 removed, so pin that it says something
        // (code review, round 1).
        #expect(
            SwitchOutcomeReading.note(response)?.isEmpty == false
        )
    }

    @Test("A switch that DID move the screen reports switched: true")
    func aRealSwitchReportsTheSwitch() {
        // The discriminator is the point: a payload on the
        // stand-down alone would still leave a caller reading
        // presence-vs-absence, which on the Lua channel is truthy
        // exactly when nothing happened.
        let switched = KiwiCore.DesktopSwitchOutcome.switched
        #expect(switched.response.isSuccess)
        #expect(
            SwitchOutcomeReading.switched(switched.response) == true
        )
        // The note belongs to the stand-down: a blanket note would
        // satisfy the assertion above while telling a caller
        // nothing (prover round 1).
        #expect(SwitchOutcomeReading.note(switched.response) == nil)
    }

    @Test("The stand-down is logged, naming the verb and the event")
    func standDownIsLogged() {
        final class Box: @unchecked Sendable {
            var lines: [String] = []
        }
        pinTopology()
        defer { resetAuthorityOverrides() }
        let core = makeTestCore()
        let box = Box()
        core.onLog = { box.lines.append($0) }

        let outcome = core.switchDesktop(
            to: shownTarget(),
            verb: "move_to_desktop_and_follow"
        )
        // Derived from the payload rather than a literal: the line
        // must name the same EVENT the caller was answered with. A
        // line carrying the verb beside another event's wording —
        // the bridge refusal, say — read as green while the trace
        // lied (prover round 1).
        guard let note = SwitchOutcomeReading.note(outcome.response),
            !note.isEmpty
        else {
            Issue.record("the stand-down answered no note")
            return
        }
        // The verb, because the trace has to say WHICH caller
        // stood down — the two share this dispatch.
        #expect(
            box.lines.contains {
                $0.contains("move_to_desktop_and_follow")
                    && $0.contains(note)
            }
        )
    }
}
