import Foundation
import Testing

/// The escape's two doors (#2173): one writer of the live float
/// rules, so a changed guess is always judged, and one derivation
/// of the overlay flag, which track and every recheck take.
@Suite("Automatic float seams (#2173)")
struct AutoFloatSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("installFloatRules is the one writer of the live float rules")
    func oneWriter() throws {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let hits = try SourceScan.strippedSource(at: file)
                .occurrences(of: "eventLoop.floatRules =")
            if hits > 0 { found[file.lastPathComponent] = hits }
        }
        #expect(found == ["KiwiCore+AutoFloat.swift": 1])
    }

    @Test("track and the recheck take the one overlay derivation")
    func oneOverlayDerivation() throws {
        let tracking = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Events/EventLoop+Tracking.swift"
            )
        )
        #expect(
            tracking.contains("window.isTransientOverlay = Self.isOverlay(")
        )
        #expect(tracking.occurrences(of: "Self.isOverlay(") >= 3)
        #expect(tracking.contains(".windowOverlayChanged(id, isOverlay:"))
    }
}
