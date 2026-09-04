import Foundation
import Testing

@testable import KiwiDeskCore

/// `desktop_change`'s #888 display dimension: which display
/// switched, and to which Desktop — both read from the handler's
/// one topology snapshot.
///
/// Serialized, synchronous bodies: see `DesktopAuthorityTests`;
/// the fixture is `DesktopAuthorityFixture.swift`.
@Suite("desktop_change display dimension (#888)", .serialized)
@MainActor
struct DesktopEventTests {
    private func makeEventCore() -> (
        core: KiwiCore,
        events: () -> [(KiwiNotification, JSONValue)]
    ) {
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        pinTwoDisplays()
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        var events: [(KiwiNotification, JSONValue)] = []
        core.bus.addSink { events.append(($0, $1)) }
        return (core, { events })
    }

    private func data(
        in events: [(KiwiNotification, JSONValue)]
    ) -> [String: JSONValue]? {
        guard
            let (_, data) = events.last(where: {
                $0.0 == .desktopChange
            }),
            case .object(let payload) = data
        else { return nil }
        return payload
    }

    /// Emits from the same pair the handler threads: one
    /// snapshot, and the diff taken once against the core's
    /// stamped reading.
    private func emit(_ core: KiwiCore) {
        let snapshot = NativeSpaces.desktopSnapshot()
        core.emitDesktopChange(
            snapshot,
            changed: core.switchedDisplays(in: snapshot).changed
        )
    }

    @Test("A secondary switch names its monitor and Desktop")
    func secondaryDimension() {
        defer { resetAuthorityOverrides() }
        let (core, events) = makeEventCore()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        emit(core)
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(2))
        #expect(payload?["desktop"] == .number(4))
    }

    @Test("A main switch is monitor 1")
    func mainDimension() {
        defer { resetAuthorityOverrides() }
        let (core, events) = makeEventCore()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        emit(core)
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(1))
        #expect(payload?["desktop"] == .number(2))
    }

    @Test("A repeated notification reports the main display")
    func repeatedNotification() {
        defer { resetAuthorityOverrides() }
        let (core, events) = makeEventCore()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        emit(core)
        let payload = data(in: events())
        #expect(payload?["monitor"] == .number(1))
        #expect(payload?["desktop"] == .number(1))
    }

    /// A display arriving on a fullscreen space emits NOTHING —
    /// the pre-#888 silence (review, 2026-08-18).
    ///
    /// The fallback used to substitute the MAIN display's Desktop
    /// here while `monitor` still named the switched one, so the
    /// event described a switch that never happened: e.g.
    /// `desktop: 1, monitor: 2`.
    @Test("A fullscreen arrival emits nothing, never a mixed pair")
    func fullscreenArrivalIsSilent() {
        defer { resetAuthorityOverrides() }
        let (core, events) = makeEventCore()
        NativeSpaces.spacesOverride = [
            authoritySpace(10, display: "UUID-A", current: true),
            authoritySpace(11, display: "UUID-A"),
            authoritySpace(20, display: "UUID-B"),
            authoritySpace(
                98,
                display: "UUID-B",
                current: true,
                isUser: false
            ),
        ]
        emit(core)
        #expect(data(in: events()) == nil)
    }
}
