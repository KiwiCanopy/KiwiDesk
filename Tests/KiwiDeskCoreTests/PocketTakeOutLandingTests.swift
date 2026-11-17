import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A take-out that maximizes again plays its brief pocket to the
/// fill, where the window lands, never to the plain frame it
/// returns to (#3408); a plain take-out plays to that frame.
@Suite("Pocket take-out landing (#3408)", .serialized)
@MainActor
struct PocketTakeOutLandingTests {
    private let one = WindowID(1)
    private let area = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let own = CGRect(x: 40, y: 40, width: 500, height: 300)

    /// w1 marked, floating at `own`, with every play drawn inert.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-landing-\(UUID().uuidString)"
                )
        )
        core.tiler.settings.kiwishelf.pocketVisibility = .hidden
        core.tiler.visibleBounds = { [area] _ in area }
        core.briefPocket.reduceMotion = { false }
        core.briefPocket.present = { _ in }
        core.briefPocket.makeFrames = { _, _ in nil }
        let element = AXUIElementCreateApplication(1)
        core.tiler.applier.elementProvider = { _ in element }
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_001,
                        appName: "App\(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        core.focusWindow(one, warp: false)
        core.execute("toggle_pocket_window")
        core.briefPocket.end()
        core.state.apply(.windowResized(one, own))
        return core
    }

    /// Puts w1 back and takes it out, answering the take-out's play.
    private func takeOut(_ core: KiwiCore) -> CGRect? {
        #expect(core.execute("pocket").isSuccess)
        core.briefPocket.end()
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
        return core.briefPocket.playing?.window
    }

    @Test("a re-maximizing take-out plays to the fill")
    func playsToTheFill() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        #expect(core.execute("toggle_maximized").isSuccess)
        let played = try #require(takeOut(core))
        #expect(played == area)
    }

    @Test("an in-place Height take-out plays to the frame it is sent")
    func inPlaceHeightPlaysToTheIssue() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let args: [JSONValue] = [
            .string("height"), .number(0.5), .string("in_place"),
        ]
        #expect(core.execute("toggle_maximized", args: args).isSuccess)
        let played = try #require(takeOut(core))
        let sent = try #require(core.tiler.commandedFrame(of: one))
        #expect(played == sent)
        #expect(played.height == area.height)
        #expect(played.width == area.width / 2)
    }

    @Test("a plain take-out plays to its frame")
    func plainPlaysToItsFrame() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let played = try #require(takeOut(core))
        #expect(played != area)
        #expect(played.size == own.size)
    }
}
