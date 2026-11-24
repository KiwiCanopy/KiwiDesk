import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// With shared Desktops on two or more screens the overview reads
/// one row per Desktop, its "shown" the Desktop's own (#3602). Two
/// screens as in `DesktopOverviewMoveTests`: Built-in (A) and DELL
/// (B), sharing Desktops 10 (shown) and 11.
@Suite("Desktop overview shared rows", .serialized)
@MainActor
struct DesktopOverviewRowTests {
    private func makeCore(shared: Bool, screens: Int = 2) -> KiwiCore {
        NativeSpaces.spacesOverride =
            shared
            ? [
                authoritySpace(10, display: "SHARED", current: true),
                authoritySpace(11, display: "SHARED"),
            ]
            : authorityTopology(mainCurrent: 10, secondaryCurrent: 20)
        pinTwoDisplays()
        PositionalDisplays.mainIDOverride = { DisplayID(1) }
        let core = makeAuthorityCore()
        let displays = [
            authorityDisplay(1, "Built-in"),
            authorityDisplay(2, "DELL", x: -100),
        ]
        connectAuthority(core, Array(displays.prefix(screens)))
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.activate("1")
        return core
    }

    private func reset() {
        resetAuthorityOverrides()
        PositionalDisplays.mainIDOverride = nil
    }

    private func overview(_ core: KiwiCore) -> DesktopOverview {
        core.desktopOverview(
            on: core.state.workspaces.placementOrWhole(of: DisplayID(1))
        )
    }

    @Test("shared Desktops on two screens read one row per Desktop")
    func sharedRows() {
        let core = makeCore(shared: true)
        defer { reset() }
        let overview = overview(core)
        #expect(
            overview.rows == [
                DesktopOverview.Row(native: 10, isShown: true),
                DesktopOverview.Row(native: 11, isShown: false),
            ]
        )
        for screen in overview.screens {
            #expect(screen.desktops.map(\.native) == [10, 11])
        }
    }

    @Test("separate Spaces read no rows")
    func separateReadsNone() {
        let core = makeCore(shared: false)
        defer { reset() }
        #expect(overview(core).rows.isEmpty)
    }

    @Test("one screen reads no rows")
    func oneScreenReadsNone() {
        let core = makeCore(shared: true, screens: 1)
        defer { reset() }
        #expect(overview(core).rows.isEmpty)
    }

    private func screen(
        _ id: UInt32,
        _ natives: [UInt64],
        shown: UInt64? = nil
    ) -> DesktopOverview.Screen {
        DesktopOverview.Screen(
            display: DisplayID(id),
            name: "S\(id)",
            isMain: id == 1,
            isHere: id == 1,
            desktops: natives.enumerated().map { index, native in
                DesktopOverview.Desktop(
                    native: native,
                    label: index + 1,
                    number: index + 1,
                    isShown: native == shown,
                    profile: nil,
                    spaces: []
                )
            }
        )
    }

    @Test("a row's shown is the Desktop's verdict, never a column's")
    func shownIsTheDesktops() {
        let rows = DesktopOverview.rows(
            of: [screen(1, [10, 11], shown: 10), screen(2, [10, 11])],
            shared: true,
            isShown: { $0 == 11 }
        )
        #expect(rows.map(\.isShown) == [false, true])
    }

    @Test("screens listing different sets read no rows")
    func mismatchReadsNone() {
        let rows = DesktopOverview.rows(
            of: [screen(1, [10, 11]), screen(2, [11, 10])],
            shared: true,
            isShown: { _ in false }
        )
        #expect(rows.isEmpty)
        let synthetic = DesktopOverview.rows(
            of: [screen(1, [0]), screen(2, [0])],
            shared: true,
            isShown: { _ in true }
        )
        #expect(synthetic.isEmpty)
    }
}
