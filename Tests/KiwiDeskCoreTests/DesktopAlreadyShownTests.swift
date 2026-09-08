import Foundation
import Testing

@testable import KiwiDeskCore

/// A switch to the Desktop already on screen answers SUCCESS
/// CARRYING A NOTE (#1336). The silence it replaces was
/// measured: `move_to_desktop_and_follow <current>` printed
/// nothing, logged nothing and exited 0, which a caller cannot
/// tell from a switch that moved the screen.
///
/// Success rather than a refusal is the ruling (owner,
/// 2026-09-08): a caller ENSURING a Desktop is shown must still
/// succeed, so only the note distinguishes the two.
///
/// No bridge fakes here on purpose — the stand-down returns
/// before `switchDesktop` reaches the bridge, so this suite
/// reaches nothing the machine owns beyond the topology
/// override the fixture already installs.
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

    @Test("The stand-down answers success carrying a note")
    func standDownCarriesANote() {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
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
        // And no longer silent — the note is what the CLI prints.
        #expect(response.data != nil)
    }

    @Test("A switch that DID move the screen stays quiet")
    func aRealSwitchCarriesNoNote() {
        // The note belongs to the stand-down alone: a blanket
        // note on every success would satisfy the assertion
        // above while telling a caller nothing, so pin the
        // other arm too.
        let switched = KiwiCore.DesktopSwitchOutcome.switched
        #expect(switched.response.isSuccess)
        #expect(switched.response.data == nil)
    }

    @Test("The stand-down is logged, naming the verb")
    func standDownIsLogged() {
        final class Box: @unchecked Sendable {
            var lines: [String] = []
        }
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        defer { resetAuthorityOverrides() }
        let core = makeTestCore()
        let box = Box()
        core.onLog = { box.lines.append($0) }

        let outcome = core.switchDesktop(
            to: shownTarget(),
            verb: "move_to_desktop_and_follow"
        )
        // Derived from the response's own payload rather than a
        // literal: the line must name the same EVENT the caller
        // was answered with. A line carrying the verb beside
        // another event's wording — the bridge refusal, say —
        // read as green while the trace lied (prover round 1).
        guard case .string(let note)? = outcome.response.data else {
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
