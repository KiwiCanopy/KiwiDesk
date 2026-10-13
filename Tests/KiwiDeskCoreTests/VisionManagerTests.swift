import AppKit
import Testing

@testable import KiwiDeskCore

/// KiwiVision's plates (#2103): one per screen, stacked below the
/// focused window, re-stacked only when the focus moves, a settle
/// pass asks or the target's own reorder event fires — every
/// order is a WindowServer round trip on the switch path (#1925).
@Suite("KiwiVision plates")
@MainActor
struct VisionManagerTests {
    private let left = DisplayID(1)
    private let right = DisplayID(2)

    private func manager() -> (VisionManager, () -> [InertVisionPlate]) {
        let vision = VisionManager()
        var made: [InertVisionPlate] = []
        vision.plateFactory = {
            let plate = InertVisionPlate()
            made.append(plate)
            return plate
        }
        vision.reduceMotion = { true }
        return (vision, { made })
    }

    private func request(
        target: CGWindowID?,
        below: CGWindowID? = nil,
        standDown: Set<DisplayID> = [],
        screens: [DisplayID]? = nil
    ) -> VisionManager.Request {
        let all = screens ?? [left, right]
        return VisionManager.Request(
            screens: all.map {
                (
                    $0,
                    CGRect(x: Int($0.raw) * 100, y: 0, width: 100, height: 80)
                )
            },
            target: target,
            below: below,
            standDown: standDown,
            dim: 0.4
        )
    }

    @Test("off draws nothing")
    func offDrawsNothing() {
        let (vision, made) = manager()
        vision.sync(request(target: 7), reassert: false)
        #expect(made().isEmpty)
    }

    @Test("on, every screen shows a plate under the target")
    func onShowsEveryScreen() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        #expect(made().count == 2)
        for plate in made() {
            #expect(plate.isShown)
            #expect(plate.orders == [7])
            #expect(plate.dim == 0.4)
        }
        #expect(made().compactMap(\.frame).map(\.minX).sorted() == [100, 200])
    }

    @Test("a ring behind the target is what the plate stacks under")
    func stacksUnderTheRing() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7, below: 70), reassert: false)
        #expect(made().allSatisfy { $0.orders == [70] })
    }

    @Test("the same target re-stacks only when a settle pass asks")
    func sameTargetOrdersOnce() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        vision.sync(request(target: 7), reassert: false)
        #expect(made().allSatisfy { $0.orders == [7] })
        vision.sync(request(target: 7), reassert: true)
        #expect(made().allSatisfy { $0.orders == [7, 7] })
        vision.sync(request(target: 8), reassert: false)
        #expect(made().allSatisfy { $0.orders == [7, 7, 8] })
    }

    @Test("nothing focused shows no fresh plate")
    func noTargetNoPlateShown() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: nil), reassert: false)
        #expect(made().allSatisfy { !$0.isShown && $0.orders.isEmpty })
    }

    @Test("a screen standing down hides, and re-stacks on its return")
    func standDownHides() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        vision.sync(
            request(target: 7, standDown: [left]),
            reassert: false
        )
        let byFrame = Dictionary(
            uniqueKeysWithValues: made().map { ($0.frame?.minX ?? 0, $0) }
        )
        #expect(byFrame[100]?.isShown == false)
        #expect(byFrame[200]?.isShown == true)
        vision.sync(request(target: 7), reassert: false)
        #expect(byFrame[100]?.isShown == true)
        #expect(byFrame[100]?.orders == [7, 7])
        #expect(byFrame[200]?.orders == [7])
    }

    @Test("a screen that leaves drops its plate")
    func goneScreenDrops() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        vision.sync(request(target: 7, screens: [right]), reassert: false)
        #expect(vision.plates.keys.sorted { $0.raw < $1.raw } == [right])
        #expect(made().filter(\.isShown).count == 1)
    }

    @Test("off fades every plate out")
    func offHidesAll() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        vision.isOn = false
        vision.sync(request(target: 7), reassert: false)
        #expect(made().allSatisfy { !$0.isShown })
        #expect(!vision.hasShownPlates)
    }

    @Test("the target's reorder event re-stacks; another window's does not")
    func restackFollowsTheTarget() {
        let (vision, made) = manager()
        vision.isOn = true
        vision.sync(request(target: 7, below: 70), reassert: false)
        vision.restack(below: 9)
        #expect(made().allSatisfy { $0.orders == [70] })
        vision.restack(below: 7)
        #expect(made().allSatisfy { $0.orders == [70, 7] })
    }

    @Test("clear turns the mode off and says so")
    func clearAnnounces() {
        let (vision, _) = manager()
        var heard: [Bool] = []
        vision.onChange = { heard.append($0) }
        vision.isOn = true
        vision.sync(request(target: 7), reassert: false)
        vision.clear()
        #expect(!vision.isOn)
        #expect(vision.plates.isEmpty)
        #expect(heard == [false])
    }
}
