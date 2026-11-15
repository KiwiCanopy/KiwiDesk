import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The edges of #2756's plan and write: what a crossing reports,
/// which moves are never offered, a mirror, the main-screen anchor
/// and the doors' seams. Frames are global CG points, y down.
@Suite("Screen shift edges (#2756)")
struct ScreenShiftEdgeTests {
    private func screen(
        _ id: String,
        _ frame: CGRect,
        main: Bool = false
    ) -> ArrangedScreen {
        ArrangedScreen(id: id, name: id, frame: frame, isMain: main)
    }

    @Test("A crossing carries the move along its edge")
    func crossingAlongTheEdge() throws {
        let desk = [
            screen("lg", CGRect(x: -2560, y: -100, width: 2560, height: 1440)),
            screen(
                "laptop",
                CGRect(x: 0, y: 0, width: 1728, height: 1117),
                main: true
            ),
            screen(
                "dell",
                CGRect(x: 1728, y: -159, width: 2560, height: 1440)
            ),
        ]
        let shift = try #require(ScreenShiftPlan.offer(desk)?.shifts.first)
        #expect(
            shift.crossings
                == [
                    ScreenCrossing(
                        screen: "laptop",
                        delta: CGVector(dx: 0, dy: -212)
                    )
                ]
        )
    }

    @Test("Two screens moving together shift no crossing")
    func togetherIsNoCrossing() {
        let a = screen("a", CGRect(x: 0, y: 0, width: 100, height: 100))
        let b = screen("b", CGRect(x: 100, y: 0, width: 100, height: 100))
        let up = CGVector(dx: 0, dy: -10)
        let merged = ScreenShiftPlan.merge(
            [
                ScreenShift(screen: "a", delta: up, crossings: []),
                ScreenShift(screen: "b", delta: up, crossings: []),
            ],
            in: [a, b]
        )
        #expect(merged.allSatisfy { $0.crossings.isEmpty })
    }

    @Test("A shared edge is reported once, with the relative move")
    func edgeOnce() {
        let a = screen("a", CGRect(x: 0, y: 0, width: 100, height: 100))
        let b = screen("b", CGRect(x: 100, y: 0, width: 100, height: 100))
        let merged = ScreenShiftPlan.merge(
            [
                ScreenShift(
                    screen: "a",
                    delta: CGVector(dx: 0, dy: -10),
                    crossings: []
                ),
                ScreenShift(
                    screen: "b",
                    delta: CGVector(dx: 0, dy: -4),
                    crossings: []
                ),
            ],
            in: [a, b]
        )
        #expect(merged.flatMap(\.crossings).count == 1)
        #expect(
            merged.first?.crossings
                == [
                    ScreenCrossing(screen: "b", delta: CGVector(dx: 0, dy: -6))
                ]
        )
    }

    @Test("A crossing keeps only the move along its edge")
    func alongTheEdgeOnly() {
        let a = screen("a", CGRect(x: 0, y: 0, width: 100, height: 100))
        let b = screen("b", CGRect(x: 100, y: 0, width: 100, height: 100))
        let merged = ScreenShiftPlan.merge(
            [
                ScreenShift(
                    screen: "a",
                    delta: CGVector(dx: -5, dy: -10),
                    crossings: []
                )
            ],
            in: [a, b]
        )
        #expect(
            merged.first?.crossings
                == [
                    ScreenCrossing(
                        screen: "b",
                        delta: CGVector(dx: 0, dy: -10)
                    )
                ]
        )
    }

    @Test("A move never lays one screen over another")
    func noOverlap() throws {
        // Sliding the wide screen right is the shorter way to clear
        // the narrow screen's corner, but it runs into a screen it
        // never touched while every original pair stays touching;
        // the plan slides it left instead.
        let desk = [
            screen(
                "narrow",
                CGRect(x: 0, y: 0, width: 800, height: 1117),
                main: true
            ),
            screen(
                "wide",
                CGRect(x: -600, y: 1117, width: 3440, height: 1440)
            ),
            screen(
                "side",
                CGRect(x: 2900, y: 1117, width: 1000, height: 1440)
            ),
        ]
        let shift = try #require(ScreenShiftPlan.offer(desk)?.shifts.first)
        #expect(shift.screen == "wide")
        #expect(shift.delta == CGVector(dx: -2041, dy: 0))
        #expect(!ScreenShiftPlan.overlaps(desk))
    }

    @Test("A mirror is the screen itself, never a neighbour")
    func mirrorIsNoCoverer() {
        let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let desk = [screen("laptop", laptop), screen("mirror", laptop)]
        #expect(ScreenShiftPlan.boxedIn(desk).isEmpty)
    }

    @Test("Moving the main screen moves every other one instead")
    func mainAnchor() {
        let main = DisplayReading(
            id: DisplayID(1),
            uuid: "main",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            isMain: true
        )
        let side = DisplayReading(
            id: DisplayID(2),
            uuid: "side",
            bounds: CGRect(x: 100, y: -20, width: 100, height: 100),
            isMain: false
        )
        let down = CGVector(dx: 0, dy: 30)
        #expect(
            DisplayArrangement.targets(
                moves: [DisplayID(1): down],
                in: [main, side]
            ) == [DisplayID(2): CGPoint(x: 100, y: -50)]
        )
        #expect(
            DisplayArrangement.targets(
                moves: [DisplayID(2): down],
                in: [main, side]
            ) == [DisplayID(2): CGPoint(x: 100, y: 10)]
        )
    }

    @Test("The doors read and write through the tiler's seams")
    @MainActor
    func doorsTakeTheSeams() {
        let core = makeTestCore()
        #expect(core.arrangedScreens().isEmpty)
        core.state.workspaces.displays[DisplayID(7)] = Display(
            id: DisplayID(7),
            name: "Seven",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        var written: [DisplayID: CGPoint]?
        core.tiler.displayFrames = {
            [(DisplayID(7), CGRect(x: 0, y: 0, width: 100, height: 100))]
        }
        core.tiler.readArrangement = { _ in
            [
                DisplayReading(
                    id: DisplayID(7),
                    uuid: "seven",
                    bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                    isMain: false
                )
            ]
        }
        core.tiler.writeArrangement = {
            written = $0
            return true
        }
        #expect(
            core.arrangedScreens().map(\.id) == ["seven"]
        )
        #expect(core.arrangedScreens().first?.name == "Seven")
        let landed = core.applyScreenShifts([
            ScreenShift(
                screen: "seven",
                delta: CGVector(dx: 0, dy: -5),
                crossings: []
            )
        ])
        #expect(landed)
        #expect(written == [DisplayID(7): CGPoint(x: 0, y: -5)])
    }
}
