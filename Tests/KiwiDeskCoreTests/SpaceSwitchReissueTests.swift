import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space switch re-issues every frame without probing past
/// the learned bounds (#1488): `force` is an explicit apply,
/// under whose probe verdict the automatic track count and the
/// heals stand down, and the switch used to ride it — so every
/// return redrew the count's overlap the heal had just removed.
/// Display and `min_window_size` pinned (#531, #660).
@Suite("Space switch re-issues without probing (#1488)", .serialized)
@MainActor
struct SpaceSwitchReissueTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// Three own-track windows on a pinned 1200×800 display, w1
    /// carrying a corroborated 700 pt floor so the automatic
    /// count folds w2 and w3 into one column, healed by one
    /// unforced retile. What a pass ISSUES is read off the
    /// placement ledger, which every frame-set stamps (#1161) —
    /// the state frames stay put with no AX echo to move them.
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-switch-reissue-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        for asked in [CGFloat(500), CGFloat(450)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w1,
                    size: CGSize(width: asked, height: 700)
                )
                core.tiler.boundLearner.observe(
                    w1,
                    currentSize: CGSize(width: 700, height: 700),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: w1)?.minWidth == 700)
        core.state.workspaces.focus(w1, in: space)
        core.retile()
        return core
    }

    @Test("Coming back to a Space draws the healed count")
    func returnKeepsTheFold() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute("focus_space", args: [.string("2")])
        core.execute("focus_space", args: [.string("1")])
        let issued = { (id: WindowID) in
            core.tiler.placements.recent(id, at: Date())
        }
        let floored = try #require(issued(w1))
        #expect(floored.width >= 700 - 0.5)
        // The fold: w2 and w3 came back in one column.
        #expect(issued(w2)?.minX == issued(w3)?.minX)
    }

    @Test("An explicit apply still probes past the bounds")
    func explicitApplyProbes() throws {
        // The half the switch gave up, kept for the apply that
        // asked for it (#1055): the plain count, three tracks.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.retile(force: true)
        let x2 = try #require(
            core.tiler.placements.recent(w2, at: Date())?.minX
        )
        let x3 = try #require(
            core.tiler.placements.recent(w3, at: Date())?.minX
        )
        #expect(x2 != x3)
    }
}
