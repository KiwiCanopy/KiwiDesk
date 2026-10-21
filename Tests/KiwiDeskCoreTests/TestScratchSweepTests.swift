import Foundation
import Testing

/// What `TestScratch` removes and what it spares (#2518): a
/// run's own entries at its exit, a dead run's at the next claim,
/// and never a live sibling run's or an unrelated file. The sweep
/// runs against fake temp and preferences folders here, so no
/// assertion depends on the host's.
@Suite("Test scratch sweep")
struct TestScratchSweepTests {
    /// No process holds a pid this high: macOS caps pids below.
    private static let deadPID: pid_t = 999_999

    private struct Fixture {
        let temp: URL
        let preferences: URL

        init() throws {
            let base = testTemporaryDirectory.appendingPathComponent(
                "sweep-\(UUID().uuidString)",
                isDirectory: true
            )
            temp = base.appendingPathComponent("T", isDirectory: true)
            preferences = base.appendingPathComponent("P", isDirectory: true)
            for dir in [temp, preferences] {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            }
        }

        func root(_ pid: pid_t) -> String {
            "\(TestScratch.rootPrefix)\(pid)"
        }

        func plist(_ pid: pid_t) -> String {
            "\(TestScratch.defaultsPrefix)\(pid)-\(UUID().uuidString).plist"
        }

        func make(_ temps: [String], _ plists: [String]) throws {
            for name in temps {
                try FileManager.default.createDirectory(
                    at: temp.appendingPathComponent(name),
                    withIntermediateDirectories: true
                )
            }
            for name in plists {
                try Data().write(to: preferences.appendingPathComponent(name))
            }
        }

        func left() throws -> Set<String> {
            let files = FileManager.default
            return Set(
                try files.contentsOfDirectory(atPath: temp.path)
                    + files.contentsOfDirectory(atPath: preferences.path)
            )
        }
    }

    @Test("a claim sweeps dead runs and spares live ones")
    func claimSweepsTheDead() throws {
        let fixture = try Fixture()
        let own = getpid()
        let deadPlist = fixture.plist(Self.deadPID)
        let livePlist = fixture.plist(own)
        let unrelated = ["kiwi-runner", "kiwi-run-x", "other.plist"]
        try fixture.make(
            [fixture.root(Self.deadPID), fixture.root(own)]
                + unrelated.prefix(2),
            [deadPlist, livePlist, unrelated[2]]
        )
        TestScratch.sweep(
            temp: fixture.temp,
            preferences: fixture.preferences
        ) { !TestScratch.isAlive($0) }
        #expect(
            try fixture.left()
                == Set([fixture.root(own), livePlist] + unrelated)
        )
    }

    @Test("an exit sweep removes the run's own entries alone")
    func exitSweepsOwn() throws {
        let fixture = try Fixture()
        let own = getpid()
        let otherLive = getppid()
        let ownPlist = fixture.plist(own)
        let otherPlist = fixture.plist(otherLive)
        try fixture.make(
            [fixture.root(own), fixture.root(otherLive)],
            [ownPlist, otherPlist]
        )
        TestScratch.sweep(
            temp: fixture.temp,
            preferences: fixture.preferences
        ) { $0 == own }
        #expect(
            try fixture.left()
                == Set([fixture.root(otherLive), otherPlist])
        )
    }

    /// The names the sweep reads are the names the helpers mint.
    @Test("the run's root and domains carry its pid")
    func mintedNamesCarryThePID() {
        let own = getpid()
        let root = testTemporaryDirectory
        #expect(
            TestScratch.owner(
                of: root.lastPathComponent,
                prefix: TestScratch.rootPrefix
            ) == own
        )
        #expect(
            root.deletingLastPathComponent().standardizedFileURL
                == TestScratch.systemTemp.standardizedFileURL
        )
        let (_, name) = makeScratchDefaults()
        defer { TestScratch.remove(name) }
        #expect(
            TestScratch.owner(of: name, prefix: TestScratch.defaultsPrefix)
                == own
        )
    }
}
