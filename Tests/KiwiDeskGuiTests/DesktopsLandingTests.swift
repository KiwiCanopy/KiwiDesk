import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A stay-open drop whose moves land after their verbs return
/// reads the desk again on the window events until the moved
/// windows show on the target line (#3208). The overview is
/// `DesktopsStateTests.overview()`: screen 1 is KiwiHub's.
@Suite("Desktops drop waits for its landing")
struct DesktopsLandingTests {
    private static func target(
        _ overview: DesktopOverview
    ) throws -> DesktopsTarget {
        let state = DesktopsStateTests.state(overview)
        return try #require(
            state.target(DesktopsPlace(screen: 1, desktop: 1, line: 0))
        )
    }

    private static func landing(_ ids: [UInt32]) throws -> DesktopsLanding {
        DesktopsLanding(
            ids: Set(ids.map(WindowID.init)),
            target: try target(DesktopsStateTests.overview()),
            deadline: 0
        )
    }

    @Test("landed only once every moved window is on the target line")
    func landedReadsTheTargetLine() throws {
        let overview = DesktopsStateTests.overview()
        // Window 20 is on the target line; window 3 is still on its
        // old one, as the read right after a hidden-Desktop drop has
        // it.
        #expect(try Self.landing([20]).landed(in: overview))
        #expect(try !Self.landing([3]).landed(in: overview))
        #expect(try !Self.landing([20, 3]).landed(in: overview))
        // Another line of the target's Desktop is not the target.
        let state = DesktopsStateTests.state(overview)
        let other = try #require(
            state.target(DesktopsPlace(screen: 1, desktop: 1, line: 1))
        )
        let elsewhere = DesktopsLanding(
            ids: [WindowID(20)],
            target: other,
            deadline: 0
        )
        #expect(!elsewhere.landed(in: overview))
    }

    @Test("a same-numbered line on another Desktop is not the target")
    func otherDesktopIsNotTheTarget() throws {
        // Space "1" on Desktop 1 holds windows 1–7; the target is
        // Space "1" on Desktop 2.
        #expect(
            try !Self.landing([1]).landed(
                in:
                    DesktopsStateTests
                    .overview()
            )
        )
    }

    @Test("window and Desktop events read the desk again")
    func eventsThatMoveWindows() {
        let reads = KiwiNotification.allCases.filter(DesktopsLanding.reads)
        #expect(
            Set(reads)
                == [
                    .windowCreated, .windowDestroyed, .windowMovedToSpace,
                    .spaceChange, .desktopChange,
                ]
        )
    }

    /// The overview with window 3 moved off Space "1" of Desktop 1
    /// onto the target line, as its landing reads.
    private static func landedOverview() -> DesktopOverview {
        let old = DesktopsStateTests.overview()
        let screens = old.screens.enumerated().map { index, screen in
            guard index == 1 else { return screen }
            let desktops = screen.desktops.enumerated().map { d, desktop in
                let spaces = desktop.spaces.enumerated().map { l, line in
                    var windows = line.windows
                    if d == 0, l == 0 { windows.removeAll { $0.id.raw == 3 } }
                    if d == 1, l == 0 {
                        windows.append(DesktopsStateTests.window(3, "App 3"))
                    }
                    return DesktopOverview.SpaceLine(
                        space: line.space,
                        mode: line.mode,
                        isShown: line.isShown,
                        marker: line.marker,
                        windows: windows,
                        lastFocused: line.lastFocused
                    )
                }
                return DesktopOverview.Desktop(
                    native: desktop.native,
                    label: desktop.label,
                    number: desktop.number,
                    isShown: desktop.isShown,
                    profile: desktop.profile,
                    spaces: spaces
                )
            }
            return DesktopOverview.Screen(
                display: screen.display,
                name: screen.name,
                isMain: screen.isMain,
                isHere: screen.isHere,
                desktops: desktops
            )
        }
        return DesktopOverview(screens: screens, yours: old.yours)
    }

    @MainActor
    @Test("a re-read keeps the selection, the search and the refusal")
    func refreshKeepsWhatTheUserHas() throws {
        var overview = DesktopsStateTests.overview()
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { overview }
        model.setScope(.desktops)
        let first = DesktopsPlace(screen: 1, desktop: 0, line: 0)
        model.desktops?.select(window: WindowID(5), in: first)
        model.refuseDesktops("refused")
        overview = Self.landedOverview()
        model.refreshDesktops()
        let state = try #require(model.desktops)
        #expect(state.place == first)
        #expect(state.window == WindowID(5))
        #expect(model.desktopsRefusal == "refused")
        let landing = DesktopsLanding(
            ids: [WindowID(3)],
            target: try Self.target(DesktopsStateTests.overview()),
            deadline: 0
        )
        #expect(landing.landed(in: state.overview))
    }

    @MainActor
    @Test("a re-read keeps a place away from the start, and the search")
    func refreshKeepsAPlaceAndTheSearch() throws {
        var overview = DesktopsStateTests.overview()
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { overview }
        model.setScope(.desktops)
        model.setDesktopsQuery("App")
        // Space "1" of Desktop 2, which opens nothing by default.
        let away = DesktopsPlace(screen: 1, desktop: 1, line: 0)
        model.desktops?.select(away)
        overview = Self.landedOverview()
        model.refreshDesktops()
        let state = try #require(model.desktops)
        #expect(state.place == away)
        #expect(state.window == nil)
        #expect(state.query == "App")
    }

    @MainActor
    @Test("a re-read leaves a carry alone")
    func refreshWaitsOutACarry() throws {
        var overview = DesktopsStateTests.overview()
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { overview }
        model.setScope(.desktops)
        model.clickWindow(
            WindowID(5),
            in: DesktopsPlace(screen: 1, desktop: 0, line: 0),
            count: 1,
            modifiers: .command
        )
        overview = Self.landedOverview()
        model.refreshDesktops()
        #expect(model.desktops?.carried == [WindowID(5)])
        let landing = DesktopsLanding(
            ids: [WindowID(3)],
            target: try Self.target(DesktopsStateTests.overview()),
            deadline: 0
        )
        let state = try #require(model.desktops)
        #expect(!landing.landed(in: state.overview))
    }

    @Test("the controller waits after a drop and stops at a close")
    func controllerWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        func squash(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let desktops = try squash("JumpPanelController+Desktops.swift")
        #expect(
            desktops.contains(
                "model.reloadDesktops(selecting:target)letgone="
            )
        )
        #expect(desktops.occurrences(of: "awaitLanding(") == 1)
        let controller = try squash("JumpPanelController.swift")
        #expect(
            controller.contains(
                "privatefuncfadeOut(holdUnseen:TimeInterval){endLanding()"
            )
        )
        let landing = try squash("JumpPanelController+Landing.swift")
        #expect(landing.contains("landingSink=core.bus.addSink{"))
        // The bound, the in-place read and the end once it shows.
        #expect(
            landing.contains(
                "DesktopsLanding.uptime()<landing.deadline"
                    + "else{returnendLanding()}model.refreshDesktops()"
            )
        )
        #expect(
            landing.contains(
                "landing.landed(in:overview){endLanding()}"
            )
        )
        #expect(landing.contains("core.bus.removeSink(token)"))
    }
}
