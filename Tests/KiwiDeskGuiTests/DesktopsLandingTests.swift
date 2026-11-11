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
        #expect(landing.contains("core.bus.removeSink(token)"))
    }
}
