import Foundation
import Testing

/// The instant lead's lapse seam (#2882) is wired once, in
/// `KiwiCore+Bootstrap`, to the two steady syncs with no
/// re-order: a second wiring would double the sync, a missing one
/// leaves the inert default, and a `reassertOrder` adds a round
/// trip to the switch path (#1925). Both halves are held here,
/// since a lapse that heals nothing reds no behavioural suite
/// whose fixture wires its own closure.
@Suite("Instant lead lapse seam (#2882)")
struct InstantLeadLapseSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("the seam is declared, called and wired once each")
    func oneWiring() throws {
        let sites = try SourceScan.identifierSites(
            of: "instantLeadLapsed",
            under: Self.core
        )
        let files = sites.map(\.file.lastPathComponent).sorted()
        #expect(
            files == [
                "FrameApplier.swift", "FrameApplier.swift",
                "KiwiCore+Bootstrap.swift",
            ],
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }

    @Test("the wiring is the two steady syncs, no re-order")
    func wiringIsTheSteadySyncs() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+Bootstrap.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        try #require(!source.isEmpty)
        #expect(
            source.contains(
                "tiler.applier.instantLeadLapsed={[weakself]_in"
                    + "self?.updateBorders()self?.updateMarks()}"
            )
        )
    }
}
