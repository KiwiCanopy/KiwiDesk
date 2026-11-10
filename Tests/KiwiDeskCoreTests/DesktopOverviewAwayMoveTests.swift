import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktops side moves a window on a hidden Desktop (#3171):
/// every away drop takes `move_to_desktop`, a shown target included,
/// and the panel asks the verb's own verdict first. Over the #888
/// fixture (Desktops 1–2 on `UUID-A`, ids 10/11; 3–4 on `UUID-B`,
/// ids 20/21), Desktops 1 and 3 shown; the window sits on Desktop 2.
/// `WMBridge.classResolverOverride` is process-global, so serialized.
@Suite("Desktop overview: away moves (#3171)", .serialized)
@MainActor
struct DesktopOverviewAwayMoveTests {
    private let tracked = WindowID(7)
    private let away = WindowID(9)
    private let mail = SpaceID("mail")

    private func makeCore(bridge: Bool = true) -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            bridge ? desktopVerbBridgeClasses[$0] : nil
        }
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: tracked, pid: 900_002, appName: "Here")
            )
        )
        var entry = AwayWindow(
            id: away,
            pid: 900_001,
            appName: "Away",
            appBundleID: "com.example.away",
            title: "Elsewhere",
            nativeSpace: 11
        )
        entry.isUp = true
        core.state.awayWindows[away] = entry
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// `move_to_space` cannot name an away window; the bridge move
    /// onto the shown Desktop's id is `move_to_desktop`'s alone.
    @Test("onto a shown Desktop it moves through move_to_desktop")
    func shownTargetTakesTheDesktopVerb() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.awayMoveRefusal(away, toDesktop: 10, follow: false) == nil
        )
        #expect(
            core.overviewMove(away, into: mail, onDesktop: 10, follow: false)
        )
        #expect(DesktopVerbBridge.moves.map(\.1) == [10])
        #expect(
            DesktopVerbBridge.moves.map(\.0)
                == [[NSNumber(value: away.raw)]]
        )
    }

    @Test("onto a hidden Desktop it moves through move_to_desktop too")
    func hiddenTargetTakesTheDesktopVerb() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.overviewMove(away, into: mail, onDesktop: 21, follow: false)
        )
        #expect(DesktopVerbBridge.moves.map(\.1) == [21])
    }

    @Test("a tracked window is not the verdict's")
    func trackedIsNotAsked() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.awayMoveRefusal(tracked, toDesktop: 21, follow: true) == nil
        )
    }

    @Test("a follow of a hidden window refuses, a plain move does not")
    func followHiddenRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.state.awayWindows[away]?.isUp = false
        #expect(
            core.awayMoveRefusal(away, toDesktop: 21, follow: true)
                == .followHidden
        )
        #expect(
            core.awayMoveRefusal(away, toDesktop: 21, follow: false) == nil
        )
        #expect(
            !core.overviewMove(away, into: mail, onDesktop: 21, follow: true)
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("without the Desktop bridge it refuses")
    func noBridgeRefuses() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        #expect(
            core.awayMoveRefusal(away, toDesktop: 10, follow: false)
                == .noDesktopBridge
        )
        #expect(
            !core.overviewMove(away, into: mail, onDesktop: 10, follow: false)
        )
    }

    @Test("a Desktop macOS does not number is unreachable")
    func unnumberedRefuses() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.awayMoveRefusal(away, toDesktop: 99, follow: false)
                == .unreachable
        )
    }

    @Test("the verb answers with the verdict's words")
    func verbSpeaksTheVerdict() {
        let core = makeCore()
        defer { teardown() }
        core.state.awayWindows[away]?.isUp = false
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(2), .null, .number(Double(away.raw))]
        )
        #expect(response.error == AwayMoveRefusal.followHidden.message)
    }

    /// The verb fails with the verdict's own words, so the panel's
    /// reason is the one the move would give.
    @Test("a sticky window refuses a named Space in both")
    func stickyAgrees() {
        let core = makeCore()
        defer { teardown() }
        var window = ManagedWindow(
            id: away,
            pid: 900_001,
            appName: "Away",
            title: "Elsewhere"
        )
        window.stickyScope = .global
        core.state.rememberStickyIntent(of: window)
        #expect(
            core.awayMoveRefusal(away, toDesktop: 10, follow: false)
                == .sticky
        )
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail"), .number(Double(away.raw))]
        )
        #expect(response.error == AwayMoveRefusal.sticky.message)
        #expect(DesktopVerbBridge.moves.isEmpty)
    }
}
