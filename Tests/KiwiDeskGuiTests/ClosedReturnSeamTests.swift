import Foundation
import Testing

/// The #1414 close mark is written from ONE place: the gone
/// handler's `closed` arm, on its own classification. A second
/// writer beside a call site — or one outside that arm — would
/// hand a Desktop departure or a hide the grant the ruling keeps
/// for a close (#636/#913).
@Suite("The close mark has one writer, inside the closed arm (#1414)")
struct ClosedReturnSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    @Test("rememberClosedDeparture is called once, from the closed arm")
    func oneWriterInsideTheClosedArm() throws {
        let sites = try SourceScan.identifierSites(
            of: "rememberClosedDeparture(",
            under: Self.core
        )
        let calls = sites.filter {
            $0.file.lastPathComponent == "KiwiCore+GoneReason.swift"
        }
        let listed = sites.map(\.site).joined(separator: ", ")
        #expect(calls.count == 1, "found \(listed)")
        // The definition and the one call: nothing else.
        #expect(sites.count == 2, "found \(listed)")
        let handler = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "App/KiwiCore+GoneReason.swift"
            )
        )
        let arm = try #require(handler.range(of: "if reason == .closed {"))
        let call = try #require(
            handler.range(of: "rememberClosedDeparture(")
        )
        let close = try #require(
            handler.range(
                of: "\n        }",
                range: arm.upperBound..<handler.endIndex
            )
        )
        #expect(arm.upperBound < call.lowerBound)
        #expect(call.lowerBound < close.lowerBound)
    }
}
