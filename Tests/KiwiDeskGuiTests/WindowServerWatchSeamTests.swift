import Foundation
import Testing

/// One owner of the WindowServer per-window stream (#2275): only
/// `WindowServerWatch` reaches the pump, each consumer connects
/// once in its ruled home, and the watch is built in one place, so
/// no second sink can steal the pump's one weak reference.
@Suite("WindowServer watch seam")
struct WindowServerWatchSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Files under Core spelling `needle`, with their counts.
    private func sites(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let count = text.occurrences(of: needle)
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("only the watch reaches the pump")
    func oneOwnerOfThePump() throws {
        #expect(
            try sites(of: "SkyLightWindowEvents.shared")
                == ["WindowServerWatch.swift": 1]
        )
        #expect(
            try sites(of: ".attach(self)") == ["WindowServerWatch.swift": 2]
        )
        #expect(
            try sites(of: "source?.watch(") == ["WindowServerWatch.swift": 2]
        )
    }

    @Test("each consumer connects once, in its ruled home")
    func oneConnectPerConsumer() throws {
        #expect(
            try sites(of: "watch.connect(") == [
                "BorderManager+WindowServer.swift": 1
            ]
        )
        #expect(
            try sites(of: "windowServer.connect(")
                == ["KiwiCore+WindowServer.swift": 3]
        )
    }

    /// The overflow mark rides the same stream as the sticky mark
    /// (#2235): its re-assert on a restack is a panel order no Core
    /// test can read, so the wiring is needled too.
    @Test("the core connects the overflow mark's re-assert")
    func overflowRestackIsWired() throws {
        let wiring = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+WindowServer.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            wiring.occurrences(
                of: "restack:{[weakself]idinself?.overflowMarks.reassert(id)}"
            ) == 1
        )
    }

    /// The mark's restack is its #414 re-assert on a raise that
    /// fires no AX focus event; its effect is a panel order no
    /// Core test can read, so the wiring is needled.
    @Test("the core connects the mark's re-assert to the restack")
    func markRestackIsWired() throws {
        let wiring = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+WindowServer.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            wiring.occurrences(
                of: "restack:{[weakself]idinself?.stickyMarks.reassert(id)}"
            ) == 1
        )
    }

    /// A stop clears outside the verdict path, so a quit never
    /// logs a tracking state; the log arm is unreachable from a
    /// test without the live pump, so the shape is needled.
    @Test("a stop never runs the verdict path")
    func stopSkipsTheVerdict() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent("OS/WindowServerWatch.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: "func stop()", in: source)
        )
        #expect(body.occurrences(of: "submit(") == 0)
        #expect(body.occurrences(of: "onLog(") == 0)
    }

    /// An event's restack pays at the run loop turn's end (#2659):
    /// both test twins pay at once, so no Core suite sees a default
    /// that went immediate or an event arm that orders directly.
    @Test("an event's restack is owed to the turn's end")
    func eventRestackIsOwed() throws {
        #expect(
            try sites(of: "MainRunLoopTurnEnd.schedule")
                == ["WindowServerWatch.swift": 1]
        )
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent("OS/WindowServerWatch.swift")
        )
        let handle = try #require(
            SourceScan.declarationBody(after: "func handle(", in: source)
        )
        #expect(handle.occurrences(of: "oweRestack(id)") == 1)
        #expect(handle.occurrences(of: "restack(id)") == 0)
    }

    @Test("the watch is built in one place")
    func oneConstructionSite() throws {
        // The core builds its watch; BorderManager's default is a
        // test's standalone manager, never started.
        #expect(
            try sites(of: "WindowServerWatch()")
                == ["KiwiCore.swift": 1, "BorderManager.swift": 1]
        )
        // The sink is taken at start, so one door starts it.
        #expect(
            try sites(of: "windowServer.start()")
                == ["KiwiCore+BootSeams.swift": 1]
        )
        #expect(try sites(of: "watch.start()") == [:])
    }

    @Test("the core wires the watch's log and animation reads")
    func coreWiresTheWatch() throws {
        let bootstrap = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Bootstrap.swift"
            )
        )
        for needle in [
            "windowServer.onLog = log",
            "windowServer.configureFromEnvironment()",
            "connectWindowServerConsumers()",
            "windowServer.isAnimating = animationDriven",
        ] {
            #expect(bootstrap.occurrences(of: needle) == 1, "\(needle)")
        }
    }
}
