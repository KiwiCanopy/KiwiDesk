import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// A quit arranges every Space's floats, on the condition that the
/// next launch gives each its previous state back — frame, float
/// flag and Space (#1864 ruling). Process A lays the desk out and
/// quits through `CrashRecovery`'s own stop; the gather's frames
/// stand in for the moves its AX pass makes; process B scans the
/// windows where the gather left them and runs the boot tail.
@Suite("A quit gives floats their state back (#1864)", .serialized)
@MainActor
struct QuitFloatReturnTests {
    /// A hand float on each Space, a detection float, two tiles.
    private static let tiled = WindowID(1)
    private static let shownFloat = WindowID(2)
    private static let detected = WindowID(3)
    private static let hiddenTile = WindowID(11)
    private static let hiddenFloat = WindowID(13)

    private static let windows: [F.Window] = [
        .init(
            id: tiled,
            space: F.shown,
            frame: CGRect(x: 40, y: 60, width: 700, height: 500)
        ),
        .init(
            id: shownFloat,
            space: F.shown,
            frame: CGRect(x: 210, y: 230, width: 420, height: 310)
        ),
        .init(
            id: detected,
            space: F.shown,
            frame: CGRect(x: 260, y: 300, width: 380, height: 260),
            floating: true
        ),
        .init(
            id: hiddenTile,
            space: F.hidden,
            frame: CGRect(x: 120, y: 140, width: 640, height: 480)
        ),
        .init(
            id: hiddenFloat,
            space: F.hidden,
            frame: CGRect(x: 300, y: 260, width: 500, height: 400)
        ),
    ]

    private static let handFloats = [shownFloat, hiddenFloat]

    /// Process A, settled, with the two hand floats floated.
    private func processA() throws -> KiwiCore {
        let a = try #require(F.processA(Self.windows))
        a.onLog = { _ in }
        for id in Self.handFloats { a.state.setFloating(id, true) }
        _ = F.settle(a)
        return a
    }

    /// Where the quit gather leaves every window: the grid's frame
    /// for each window it places, the settled frame for the rest.
    private func gathered(_ core: KiwiCore) -> [WindowID: CGRect] {
        var left: [WindowID: CGRect] = [:]
        for window in core.state.windows.all {
            left[window.id] = window.frame
        }
        let grid = WindowGather.targets(
            state: core.state,
            primaryHeight: GeometryUtils.primaryHeight,
            style: .grid,
            minSize: core.tiler.settings.minWindowSize,
            targetDepth: core.appWide.quitGridTargetDepth
        )
        left.merge(grid) { _, gathered in gathered }
        return left
    }

    /// The quit's session file, written and read back through
    /// `CrashRecovery`'s own stop and boot read.
    private func quit(_ core: KiwiCore) throws -> StateSnapshot {
        core.crash.loginSession = { 1 }
        core.crash.bootTime = { .distantPast }
        // The autosave makes the directory the stop writes into.
        core.crash.autosave()
        core.crash.shutdownCleanly()
        return try #require(core.crash.takeBootSnapshot())
    }

    /// The scan as the next launch sees it: a hand float is not a
    /// float to detection.
    private static var scanned: [F.Window] {
        windows.map { window in
            var found = window
            if handFloats.contains(window.id) { found.floating = false }
            return found
        }
    }

    /// Folds the boot tail's frames back as their echoes, then
    /// settles: where each window ends up.
    private func landed(
        _ core: KiwiCore,
        _ issued: [(WindowID, CGRect)]
    ) -> [WindowID: CGRect] {
        for (id, frame) in issued {
            core.state.apply(.windowMoved(id, frame))
        }
        return F.settle(core)
    }

    @Test(
        "the quit gather places every Space's floats",
        .enabled(if: NSScreen.main != nil)
    )
    func gatherTakesFloats() throws {
        let a = try processA()
        let left = gathered(a)
        for id in Self.handFloats + [Self.detected] {
            #expect(
                left[id] != a.state.windows[id]?.frame,
                "w\(id.raw) was left where KiwiDesk put it"
            )
        }
    }

    @Test(
        "a relaunch gives each float its flag, Space and frame back",
        .enabled(if: NSScreen.main != nil)
    )
    func relaunchRestoresFloats() throws {
        let a = try processA()
        let before = F.settle(a)
        let capture = try #require(a.tiler.stashOriginal(Self.hiddenFloat))
        let left = gathered(a)
        let session = try quit(a)
        let (b, boot) = try #require(
            F.processB(Self.scanned, left: left, session: session)
        )
        b.onLog = { _ in }
        let after = landed(b, boot)
        for id in Self.handFloats {
            #expect(b.state.userFloated.contains(id), "w\(id.raw) tiled")
            #expect(b.state.windows[id]?.isFloating == true)
        }
        for window in Self.windows {
            #expect(
                b.state.workspaces.space(of: window.id) == window.space,
                "w\(window.id.raw) changed Space"
            )
        }
        for id in [Self.shownFloat, Self.detected] {
            #expect(
                after[id] == before[id],
                "w\(id.raw) at \(after[id]!), was \(before[id]!)"
            )
        }
        // The parked float keeps the capture the old process held,
        // not the grid frame the gather left it at.
        #expect(b.tiler.stashOriginal(Self.hiddenFloat) == capture)
        b.state.workspaces.activate(F.hidden)
        let shown = F.settle(b)
        #expect(shown[Self.hiddenFloat] == capture)
    }

    /// Its debt rides every capture as its frame does (#2008), so
    /// a wake replay or a second stop before it arrives keeps it.
    @Test(
        "a hand float that arrives after the boot tail floats",
        .enabled(if: NSScreen.main != nil),
        arguments: [false, true]
    )
    func lateArrivalFloats(waking: Bool) throws {
        let a = try processA()
        let before = F.settle(a)
        let left = gathered(a)
        let session = try quit(a)
        let late = Self.shownFloat
        let early = Self.scanned.filter { $0.id != late }
        let (b, boot) = try #require(
            F.processB(early, left: left, session: session)
        )
        b.onLog = { _ in }
        if waking {
            b.restoreAndSettleAfterWake(b.sessionSnapshot())
            let again = try #require(b.crash.stopCapture(inPlace: false))
            let owed = again.windows.first { $0.windowID == late }
            #expect(owed?.floating == true)
        }
        var arrival = try #require(Self.scanned.first { $0.id == late })
        arrival.frame = left[late]!
        let issued = F.record(b) {
            b.handle(.windowCreated(F.managed(arrival)))
        }
        let after = landed(b, boot + issued)
        #expect(b.state.userFloated.contains(late))
        #expect(b.state.workspaces.space(of: late) == F.shown)
        #expect(after[late] == before[late])
    }

    /// The race the seed beside the set closes: the activation
    /// parks a replayed float before its set's echo lands, while
    /// state still reads the quit grid's frame.
    @Test(
        "a float parked before its set lands keeps its record",
        .enabled(if: NSScreen.main != nil)
    )
    func parkBeforeTheEchoKeepsTheRecord() throws {
        let a = try processA()
        let before = F.settle(a)
        let left = gathered(a)
        let session = try quit(a)
        let b = try #require(F.makeCore())
        b.onLog = { _ in }
        b.defersEventRetiles = true
        for window in Self.scanned {
            var found = window
            found.frame = left[window.id]!
            b.handle(.windowCreated(F.managed(found)))
        }
        b.defersEventRetiles = false
        b.restore(session)
        let float = Self.shownFloat
        // The set went out; its echo has not folded in.
        #expect(b.state.windows[float]?.frame == left[float])
        b.state.workspaces.activate(F.hidden)
        b.retile()
        #expect(b.tiler.stashOriginal(float) == before[float])
    }

    /// The one autosave that carries a float (#2008): a debt owed
    /// to a window not yet arrived rides every capture, so a crash
    /// before it arrives still floats it at the next launch.
    @Test(
        "an owed hand float rides an autosave across a crash",
        .enabled(if: NSScreen.main != nil)
    )
    func owedFloatRidesACrash() throws {
        let a = try processA()
        let left = F.settle(a)
        let session = try quit(a)
        let late = Self.shownFloat
        let early = Self.scanned.filter { $0.id != late }
        let (b, _) = try #require(
            F.processB(early, left: left, session: session)
        )
        b.onLog = { _ in }
        #expect(b.state.restoredFrames[late]?.floating == true)
        b.crash.loginSession = { 1 }
        b.crash.bootTime = { .distantPast }
        // No stop follows: the next launch reads the autosave.
        b.crash.autosave()
        let crashed = try #require(b.crash.takeBootSnapshot())
        let owed = crashed.windows.first { $0.windowID == late }
        #expect(owed?.floating == true)
        let (c, _) = try #require(
            F.processB(Self.scanned, left: left, session: crashed)
        )
        #expect(c.state.userFloated.contains(late))
    }

    /// The update relaunch onto this build reads an in-place file
    /// an older build wrote, its hand float inside the session. The
    /// fixture is this build's own file with the float moved back
    /// there, never hand-written JSON.
    @Test(
        "a pre-#1864 in-place file's session float still floats",
        .enabled(if: NSScreen.main != nil)
    )
    func legacySessionFloatFloats() throws {
        let a = try processA()
        let left = F.settle(a)
        let file = try #require(a.crash.stopCapture(inPlace: true))
        var json = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(file))
                as? [String: Any]
        )
        var windows = try #require(json["windows"] as? [[String: Any]])
        var moved = 0
        for index in windows.indices
        where windows[index]["floating"] as? Bool == true {
            windows[index].removeValue(forKey: "floating")
            var session =
                windows[index]["session"] as? [String: Any] ?? [:]
            session["floating"] = true
            windows[index]["session"] = session
            moved += 1
        }
        #expect(moved == Self.handFloats.count)
        json["windows"] = windows
        let old = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        for id in Self.handFloats {
            let record = old.windows.first { $0.windowID == id }
            #expect(record?.floating == true)
        }
        let (b, _) = try #require(
            F.processB(Self.scanned, left: left, session: old)
        )
        for id in Self.handFloats {
            #expect(b.state.userFloated.contains(id), "w\(id.raw) tiled")
        }
    }

    @Test(
        "a stop carries the hand floats; an autosave carries none",
        .enabled(if: NSScreen.main != nil)
    )
    func onlyAStopCarries() throws {
        func marked(_ snapshot: StateSnapshot) -> Set<WindowID> {
            Set(
                snapshot.windows.filter { $0.floating == true }
                    .map(\.windowID)
            )
        }
        let a = try processA()
        a.crash.loginSession = { 1 }
        a.crash.bootTime = { .distantPast }
        a.crash.autosave()
        // No session file yet: the boot read takes the autosave.
        let autosaved = try #require(a.crash.takeBootSnapshot())
        #expect(!autosaved.windows.isEmpty)
        #expect(marked(autosaved).isEmpty)
        #expect(marked(try quit(a)) == Set(Self.handFloats))
        a.crash.autosave()
        a.crash.shutdownCleanly(inPlace: true)
        let inPlace = try #require(a.crash.takeBootSnapshot())
        #expect(marked(inPlace) == Set(Self.handFloats))
    }
}
