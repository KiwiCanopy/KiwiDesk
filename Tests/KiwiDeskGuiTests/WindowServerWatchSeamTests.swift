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
            try sites(of: "source?.watch(") == ["WindowServerWatch.swift": 1]
        )
    }

    @Test("each consumer connects once, in its ruled home")
    func oneConnectPerConsumer() throws {
        #expect(
            try sites(of: "watch.connect(") == [
                "BorderManager+SkyLight.swift": 1
            ]
        )
        #expect(
            try sites(of: "windowServer.connect(")
                == ["KiwiCore+WindowServer.swift": 2]
        )
    }

    @Test("the watch is built in one place")
    func oneConstructionSite() throws {
        #expect(
            try sites(of: "WindowServerWatch()")
                == ["BorderManager.swift": 1]
        )
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
