import Foundation
import Testing

/// The production wiring of the dispatch-time in-flight stamp
/// (#1213) that no unit test reaches.
///
/// `StickyReachDispatchStampTests` drives the stamp through the
/// real `focus_desktop` dispatch and asserts on the set the
/// removal gate reads. What it cannot see is the SHAPE the
/// wiring must keep: the stamp lives inside `switchDesktop`
/// behind the accepted set, once — a second caller would
/// promise a flight nothing dispatched, and a caller ahead of
/// the bridge's answer would promise one for a refused switch.
@Suite("The dispatch-time in-flight stamp stays wired (#1213)")
struct StickyReachDispatchSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    @Test("the stamp is called exactly once, from the switch dispatch")
    func stampIsCalledOnceFromTheDispatch() throws {
        let needle = "stampStickyReachInFlight(forSwitchOn:"
        let sites = try SourceScan.identifierSites(
            of: needle,
            under: Self.core
        )
        #expect(
            sites.count == 1,
            """
            expected exactly one `\(needle)`, found \
            \(sites.count): \
            \(sites.map(\.site).joined(separator: ", "))
            """
        )
        #expect(
            sites.allSatisfy {
                $0.file.lastPathComponent
                    == "KiwiCore+DesktopSwitch.swift"
            }
        )
    }

    /// Behind the accepted set: the stamp must follow the switch
    /// stamp `lastDesktopSwitch = Date()`, which itself sits past
    /// the bridge's guard — a refused set moves nothing.
    @Test("the stamp sits after the switch stamp in switchDesktop")
    func stampFollowsTheAcceptedSet() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Commands")
                .appendingPathComponent("KiwiCore+DesktopSwitch.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func switchDesktop",
                in: source
            )
        )
        let switchStamp = try #require(
            body.range(of: "lastDesktopSwitch = Date()")
        )
        let flightStamp = try #require(
            body.range(of: "stampStickyReachInFlight(forSwitchOn:")
        )
        #expect(switchStamp.upperBound <= flightStamp.lowerBound)
    }
}
