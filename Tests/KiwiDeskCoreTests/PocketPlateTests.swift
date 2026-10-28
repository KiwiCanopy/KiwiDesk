import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket plate (#2678): on screen under Several windows while
/// two windows are inside, widened for its count away from a side
/// edge, and a click lists the windows inside, each row taking its
/// window out.
@Suite("Pocket plate", .serialized)
@MainActor
struct PocketPlateTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let three = WindowID(3)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-plate-\(UUID().uuidString)")
        )
        for raw: UInt32 in [3, 2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        return core
    }

    /// `one` and `two` marked and put in, through the keys.
    private func pocketTwo(_ core: KiwiCore) {
        core.execute("pocket.set_capacity", args: [.string("several")])
        for id in [one, two] {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
        }
    }

    @Test("the plate shows under Several windows from two inside")
    func showsFromTwo() {
        typealias Core = KiwiCore
        #expect(!Core.pocketPlateShows(capacity: .several, inside: [one]))
        #expect(Core.pocketPlateShows(capacity: .several, inside: [one, two]))
        #expect(!Core.pocketPlateShows(capacity: .one, inside: [one, two]))
        #expect(!Core.pocketPlateShows(capacity: .several, inside: []))
    }

    @Test("the count widens the plate away from a side edge")
    func widensAwayFromTheEdge() {
        let square = CGRect(x: 100, y: 200, width: 40, height: 40)
        let right = KiwiCore.pocketPlateFrame(
            square: square,
            extra: 20,
            edge: .right
        )
        #expect(right.maxX == square.maxX)
        #expect(right.width == 60)
        let left = KiwiCore.pocketPlateFrame(
            square: square,
            extra: 20,
            edge: .left
        )
        #expect(left.minX == square.minX)
        let bottom = KiwiCore.pocketPlateFrame(
            square: square,
            extra: 20,
            edge: .bottom
        )
        #expect(bottom.midX == square.midX)
        #expect(bottom.height == square.height)
    }

    @Test("the plate's list is a click-held list of the windows inside")
    func listSource() {
        let source = BarPeekSource.pocket([one, two])
        #expect(source.isList)
        #expect(source.clickGrowth == .outOfItem)
        #expect(source.header == .full)
        #expect(source.windows == [one, two])
    }

    @Test("a row of the plate's list takes its window out")
    func rowTakesOut() {
        let core = makeCore()
        pocketTwo(core)
        #expect(core.state.pocketedWindows == [one, two])
        core.pickBarRow(one, on: nil)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
    }

    @Test("One window shows no plate, however many are inside")
    func oneWindowHides() {
        let core = makeCore()
        pocketTwo(core)
        core.execute("pocket.set_capacity", args: [.string("one")])
        #expect(core.pocketPlateSpec(standingDown: []) == nil)
        core.updateBars()
        #expect(core.pocketPlate.shown == nil)
    }
}
