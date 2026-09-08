import Foundation
import Testing

@testable import KiwiDeskCore

/// The close-return stand-down's fourth arm (#1345): a window
/// that LEFT WITH ITS DESKTOP — `vanished`, and not a move verb's
/// own latched departure — is not a close, so the raise of the
/// fold's successor pick stands down and macOS picks the focus
/// on the Desktop it shows. Driven through `handle`: the raise
/// itself sits behind live AX (`CloseReturnStandDownWiringTests`'
/// note), so the decision line is the observable. Serialized: the
/// topology override is process-global.
@Suite("Close-return stand-down: left with the Desktop (#1345)", .serialized)
@MainActor
struct DesktopDepartureStandDownTests {
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-departure-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid_t(raw),
                        appName: "App\(raw)"
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        return core
    }

    @Test("Vanished and unlatched is a departure; latched or closed is not")
    func departurePredicate() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        let id = WindowID(1)
        let gone = KiwiEvent.windowDestroyed(id, wasMinimized: false)
        #expect(core.departedWithDesktop(gone, reason: .vanished))
        #expect(!core.departedWithDesktop(gone, reason: .closed))
        #expect(!core.departedWithDesktop(gone, reason: .minimized))
        #expect(!core.departedWithDesktop(gone, reason: nil))
        // A hide names no gone window: never a departure.
        #expect(
            !core.departedWithDesktop(
                .windowHidden(id),
                reason: .vanished
            )
        )
        core.moveLatch.stamp(id)
        #expect(!core.departedWithDesktop(gone, reason: .vanished))
    }

    @Test("The predicate's departure arm stands the raise down")
    func predicateArm() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        let destroy = KiwiEvent.windowDestroyed(
            WindowID(1),
            wasMinimized: false
        )
        #expect(
            core.eventLoop.closeReturnRaiseStandsDown(
                after: destroy,
                departedWithDesktop: true
            )
        )
        #expect(
            !core.eventLoop.closeReturnRaiseStandsDown(
                after: destroy,
                departedWithDesktop: false
            )
        )
    }

    /// The focused window vanishes onto the Desktop nobody shows
    /// — a swipe's removal — and the decision line says the
    /// raise stood down.
    @Test("A swipe's removal of the focused window stands the raise down")
    func swipeRemovalStandsDown() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        let decision = log.first { $0.contains("close-return: removed") }
        #expect(decision?.contains("departed=true") == true)
        #expect(decision?.contains("standsDown=true") == true)
    }

    /// The same vanish under a move verb's latch is the verb's
    /// own hand-off: the raise proceeds.
    @Test("A move verb's latched departure keeps the raise")
    func latchedDepartureKeepsTheRaise() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        core.moveLatch.stamp(WindowID(1))
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        let decision = log.first { $0.contains("close-return: removed") }
        #expect(decision?.contains("departed=false") == true)
        #expect(decision?.contains("standsDown=false") == true)
    }

    /// A window hosted nowhere is a close: the raise proceeds.
    @Test("A genuine close keeps the raise")
    func closeKeepsTheRaise() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowDestroyed(WindowID(1), wasMinimized: false))
        let decision = log.first { $0.contains("close-return: removed") }
        #expect(decision?.contains("departed=false") == true)
        #expect(decision?.contains("standsDown=false") == true)
    }
}
