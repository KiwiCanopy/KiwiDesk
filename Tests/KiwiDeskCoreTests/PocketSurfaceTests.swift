import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What the pocket shows and carries (#2446): its own mark while
/// out, nothing while pocketed, a Pocket row in the window switcher
/// that takes it out, KiwiVision's clear pair, and the in-place
/// restart's slot.
@Suite("Pocket surfaces", .serialized)
@MainActor
struct PocketSurfaceTests {
    private let one = WindowID(1)
    private let two = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-surface-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [2, 1] {
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
        core.state.apply(.windowFocused(one))
        return core
    }

    private func spec(_ core: KiwiCore) -> StickyMarkManager.Spec? {
        core.stickyMarkSpecs().first { $0.window == one }
    }

    @Test("out of the pocket it wears the pocket mark alone")
    func outWearsPocketMark() {
        let core = makeCore()
        core.execute("pocket")
        core.execute("pocket")
        #expect(spec(core)?.glyphs == [.pocket])
    }

    @Test("pocketed it wears no mark")
    func pocketedWearsNothing() {
        let core = makeCore()
        core.execute("pocket")
        #expect(spec(core) == nil)
    }

    @Test("the switcher lists it last, as pocketed")
    func jumpListsItLast() {
        let core = makeCore()
        core.execute("pocket")
        let entries = core.jumpEntries()
        #expect(entries.last?.target == .window(one))
        #expect(entries.last?.status == .pocketed)
        #expect(entries.filter(\.isPocketed).count == 1)
    }

    @Test("a switcher pick takes it out")
    func jumpTakesItOut() {
        let core = makeCore()
        core.execute("pocket")
        core.jump(to: .window(one))
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    @Test("KiwiVision keeps the pocket and its window clear")
    func visionPair() {
        let core = makeCore()
        core.execute("pocket")
        #expect(core.visionPocketPair().isEmpty)
        core.state.apply(.windowFocused(two))
        core.execute("pocket")
        #expect(core.visionPocketPair() == [one, two])
    }

    @Test("an in-place restart keeps the window pocketed")
    func inPlaceCarries() throws {
        let core = makeCore()
        core.execute("pocket")
        let snapshot = core.state.inPlaceSnapshot(monocleShown: [:])
        let data = try JSONEncoder().encode(snapshot)
        let read = try JSONDecoder().decode(StateSnapshot.self, from: data)
        #expect(read.pocket?.window == one)
        let next = makeCore()
        #expect(next.state.workspaces.space(of: one) != nil)
        next.state.adopt(read)
        #expect(next.state.pocketPhase(of: one) == .pocketed)
        #expect(next.state.workspaces.space(of: one) == nil)
    }

    @Test("a plain snapshot carries no pocket")
    func plainSnapshotCarriesNone() {
        let core = makeCore()
        core.execute("pocket")
        #expect(core.state.snapshot().pocket == nil)
    }
}
