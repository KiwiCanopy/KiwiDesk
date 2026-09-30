import Foundation
import Testing

/// Adopting a set's pins keeps a temporary Space's own (#1790): a
/// whole-map `spacePins =` write in Core goes through the one
/// `keepingPins(of:over:)`, or a New Space made on the second
/// screen moves to main at the next reconnect. Two sites had
/// missed it before this guard; the exemptions are listed with
/// their reason.
@Suite("Temporary pin seam (#1790)")
struct TemporaryPinSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// File → whole-map writes that may skip `keepingPins`, and why.
    private static let allowed: [String: (Int, String)] = [
        "App/KiwiCore+Reset.swift":
            (1, "resetting every setting clears every pin")
    ]

    @Test("every whole-map pin write keeps the temporary pins")
    func pinWritesKeepTemporaries() throws {
        var bare: [String: Int] = [:]
        var routed = 0
        for file in try SourceScan.swiftSources(under: Self.root) {
            let text = try SourceScan.strippedSource(at: file)
            let writes =
                text.occurrences(of: "spacePins = ")
                - text.occurrences(of: ".spacePins = ")
            let kept = text.occurrences(of: "spacePins = keepingPins(")
            routed += kept
            if writes > kept {
                let key = String(
                    file.path.dropFirst(Self.root.path.count + 1)
                )
                bare[key] = writes - kept
            }
        }
        #expect(routed >= 5, "the scan found the routed writes")
        #expect(bare == Self.allowed.mapValues(\.0))
    }
}
