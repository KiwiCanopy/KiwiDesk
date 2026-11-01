import Foundation
import Testing

/// The one "was this arrival created" door (#2630,
/// state-and-layout.md ▸ the #2478 bullet). Every test core keeps
/// `WindowCreateLedger` closed, so a reader of the ledger beside
/// the door, or an unwired consumer, leaves the behaviour suites
/// green: each needle is pinned by exact count and to its file.
@Suite("Arrival provenance has one door (#2630)")
struct ArrivalProvenanceSeamTests {
    private static let core = SourceScan.repoRoot(
        from: #filePath
    ).appendingPathComponent("Sources/KiwiDeskCore")
    private static let door = "ArrivalProvenance.swift"
    private static let wiring = "KiwiCore+ArrivalProvenance.swift"

    /// needle → the one file that carries it, and how often.
    private static let wirings: [(String, String, Int)] = [
        // The ledger's one reader, inside the door.
        ("ledger.createdAt(", door, 1),
        // The door's one asker, then its consumers: the event
        // reason and the #2478 follow.
        ("arrivals.provenance(", wiring, 1),
        ("provenance = arrivalProvenance(window)", wiring, 1),
        (
            "switch arrivalProvenance(window)",
            "KiwiCore+LaunchFollow.swift", 1
        ),
        (
            "announceArrival(window, effects: effects)",
            "KiwiCore+Events.swift", 1
        ),
        // The resolutions: a create, the bound, a destroy, a re-key.
        (
            "resolveArrivalCreated(id)",
            "KiwiCore+WindowServerWakeUp.swift", 1
        ),
        ("self?.resolveExpiredArrivals()", wiring, 1),
        ("flushHeldArrival(id)", "KiwiCore+Emitters.swift", 1),
        ("flushHeldArrival(old)", "KiwiCore+RekeyEvent.swift", 1),
        ("arrivals.reset()", "KiwiCore+Lifecycle.swift", 1),
        // The two adoption facts the event loop hands the door.
        (
            "arrivingFromAXCreate = true",
            "EventLoop+Notifications.swift", 1
        ),
        ("eventLoop.adoptsAsBootStep(pid:", wiring, 1),
    ]

    @Test("each wiring exists exactly as often as pinned, in its file")
    func wiringsArePinned() throws {
        for (needle, file, count) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == count
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                """
                expected \(count)× `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// A second reader of "was it created" would be a second
    /// late-create resolution: the class, not one spelling.
    @Test("nothing outside the door reads the create ledger")
    func ledgerHasOneReader() throws {
        let sites = try SourceScan.identifierSites(
            of: "createdAt(",
            under: Self.core
        )
        #expect(
            Set(sites.map(\.file.lastPathComponent))
                == [Self.door, "WindowCreateLedger.swift"],
            "found: \(sites.map(\.site))"
        )
    }

    /// The event never decides its reason beside the door.
    @Test("the arrival's reason is classified in the door alone")
    func classifiedOnce() throws {
        let sites = try SourceScan.identifierSites(
            of: "WindowAppearReason.classify(",
            under: Self.core
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent == Self.wiring,
            "found: \(sites.map(\.site))"
        )
    }
}
