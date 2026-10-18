import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The desk the hold suites share: a "Writing" lens over the Notes
/// app, its windows, and windows the lens leaves out, on one
/// Space with an inert plate recording its orders.
@MainActor
enum VisionHoldFixture {
    static let member = WindowID(1)
    static let stranger = WindowID(2)
    static let other = WindowID(3)
    static let notes: pid_t = 900_101
    static let strangers: pid_t = 900_102

    static func core(
        lens extra: [String: JSONValue] = [:],
        windows: [ManagedWindow] = []
    ) -> (KiwiCore, InertVisionPlate) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-vision-hold-\(UUID())")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.eventLoop.ownKeyWindow = { nil }
        core.windowServer.override = { _ in true }
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        let base = [
            window(member, notes, "test.kiwi.notes", "Draft"),
            window(
                stranger,
                strangers,
                "test.kiwi.other",
                "Mail",
                frame: CGRect(x: 640, y: 120, width: 330, height: 210)
            ),
            window(other, strangers + 1, "test.kiwi.third", "Chat"),
        ]
        for window in base + windows {
            core.state.apply(.windowCreated(window))
        }
        focus(core, member)
        var lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string("test.kiwi.notes")]),
        ]
        lens.merge(extra) { $1 }
        core.execute("kiwivision.define_lens", args: [.object(lens)])
        core.execute("kiwivision.toggle", args: [.string("Writing")])
        return (core, plate)
    }

    static func window(
        _ id: WindowID,
        _ pid: pid_t,
        _ bundle: String,
        _ title: String,
        frame: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300)
    ) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid,
            appName: "App",
            appBundleID: bundle,
            title: title,
            frame: frame
        )
    }

    /// Moves the focus to `id` and re-draws, as a focus report's
    /// `updateBorders` does.
    static func focus(_ core: KiwiCore, _ id: WindowID) {
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.focus(id, in: space)
        core.updateVision()
    }
}

/// A lens's delayed clear (#2103 rulings 12, 30, 34): a landing on
/// a window the lens leaves out waits under the haze, the plates
/// ordered above it, until the deadline, a click on it, a focus
/// elsewhere or the lens letting go.
@Suite("KiwiVision lens hold", .serialized)
@MainActor
struct KiwiVisionHoldTests {
    private typealias F = VisionHoldFixture

    @Test("a landing the lens leaves out waits above the plate")
    func landingHolds() {
        let (core, plate) = F.core()
        #expect(core.vision.hold == nil)
        F.focus(core, F.stranger)
        #expect(core.vision.hold?.window == F.stranger)
        #expect(plate.ordersAbove.last == F.stranger.raw)
        #expect(core.visionRequest().holding == F.stranger.raw)
        #expect(core.deferred.isScheduled(.visionHold))
    }

    @Test("a member's landing clears at once")
    func memberLandsClear() {
        let (core, plate) = F.core()
        F.focus(core, F.stranger)
        F.focus(core, F.member)
        #expect(core.vision.hold == nil)
        #expect(plate.orders.last == F.member.raw)
        #expect(!core.deferred.isScheduled(.visionHold))
    }

    @Test("a focus to another left-out window holds that one")
    func newTargetReplacesTheHold() {
        let (core, _) = F.core()
        F.focus(core, F.stranger)
        F.focus(core, F.other)
        #expect(core.vision.hold?.window == F.other)
    }

    @Test("the held window's reorder re-orders the plate above it")
    func reorderReordersAbove() {
        let (core, plate) = F.core()
        F.focus(core, F.stranger)
        let above = plate.ordersAbove.count
        let below = plate.orders.count
        // One shared fake plate per screen: the host's count.
        let shown = core.vision.plates.values.filter(\.isShown).count
        #expect(shown > 0)
        core.visionWindowRestacked(F.stranger)
        #expect(plate.ordersAbove.count == above + shown)
        #expect(plate.orders.count == below)
    }

    @Test("a click on the held window clears it; elsewhere does not")
    func clickClears() {
        let (core, plate) = F.core()
        F.focus(core, F.stranger)
        core.lastLeftClick = (core.wallClock(), .zero, F.other)
        core.visionPressed()
        #expect(core.vision.hold != nil)
        core.lastLeftClick = (core.wallClock(), .zero, F.stranger)
        core.visionPressed()
        #expect(core.vision.hold == nil)
        #expect(plate.orders.last == F.stranger.raw)
        #expect(!core.deferred.isScheduled(.visionHold))
    }

    @Test("a click that lands the focus never waits")
    func clickedLandingNeverWaits() {
        let (core, _) = F.core()
        core.lastLeftClick = (core.wallClock(), .zero, F.stranger)
        F.focus(core, F.stranger)
        #expect(core.vision.hold == nil)
    }

    @Test("the deadline clears the window and re-stacks below it")
    func deadlineClears() async {
        let (core, plate) = F.core()
        core.deferred.sleep = { _ in }
        F.focus(core, F.stranger)
        let deadline = core.deferred.task(for: .visionHold)
        #expect(deadline != nil)
        await deadline?.value
        #expect(core.vision.hold == nil)
        #expect(plate.orders.last == F.stranger.raw)
    }

    @Test("turning the lens off ends the hold")
    func lensOffEnds() {
        let (core, _) = F.core()
        F.focus(core, F.stranger)
        core.execute("kiwivision.toggle", args: [.string("Writing")])
        #expect(core.vision.hold == nil)
        #expect(!core.deferred.isScheduled(.visionHold))
    }

    @Test("Keep focus off ends the hold and holds nothing more")
    func keepFocusOffEnds() {
        let (core, _) = F.core()
        F.focus(core, F.stranger)
        core.execute(
            "kiwivision.define_lens",
            args: [
                .object([
                    "name": .string("Writing"),
                    "apps": .array([.string("test.kiwi.notes")]),
                    "keep_focus": .bool(false),
                ])
            ]
        )
        #expect(core.vision.hold == nil)
        F.focus(core, F.other)
        #expect(core.vision.hold == nil)
    }

    @Test("a delay of 0, or plain KiwiVision, holds nothing")
    func noDelayNoHold() {
        let (core, _) = F.core(lens: ["clear_delay": .number(0)])
        F.focus(core, F.stranger)
        #expect(core.vision.hold == nil)
        let (plain, _) = F.core()
        plain.setKiwiVision(.plain)
        F.focus(plain, F.stranger)
        #expect(plain.vision.hold == nil)
    }

    @Test("a held window is hazed in front of the mask")
    func maskHazesTheHeldWindow() {
        let (core, _) = F.core(lens: ["clear_wallpaper": .bool(true)])
        F.focus(core, F.stranger)
        let windows = core.visionRequest().windows
        let held = GeometryUtils.flip(
            core.state.windows[F.stranger]!.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(windows.first?.frame == held)
        #expect(windows.first?.clear == false)
    }

    @Test("turning a lens on over a left-out window holds nothing")
    func turningOnIsNoLanding() {
        let (core, _) = F.core()
        core.execute("kiwivision.toggle", args: [.string("Writing")])
        F.focus(core, F.stranger)
        core.execute("kiwivision.toggle", args: [.string("Writing")])
        #expect(core.vision.hold == nil)
    }

    @Test("a landing after nothing was focused still waits")
    func landingAfterNothingFocused() {
        let (core, _) = F.core()
        for id in [F.member, F.stranger, F.other] {
            core.state.apply(.windowDestroyed(id, wasMinimized: false))
        }
        core.updateVision()
        #expect(!core.vision.hasShownPlates)
        let late = WindowID(20)
        core.state.apply(
            .windowCreated(
                F.window(late, F.strangers, "test.kiwi.other", "Mail")
            )
        )
        F.focus(core, late)
        #expect(core.vision.hold?.window == late)
    }
}
