import Foundation
import Testing

/// Both `makeTestCore` twins pin the #1385 measurement's opt-in
/// read off, so a developer's `defaults write -g RestoreKeyLog`
/// never reaches a test run (tests.md, host state). A sibling of
/// `KeyWindowStreamPinTests`; removed with the measurement.
@Suite("Restore-key opt-in pin (#1385)")
struct RestoreKeyLogPinTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("makeTestCore pins the restore-key opt-in off in both twins")
    func twinsPinTheOptIn() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
            )
            // Scoped to the factory: a pin anywhere else is dead.
            let body = SourceScan.declarationBody(
                after: "func makeTestCore(",
                in: source
            )
            #expect(
                body?.contains(
                    "core.crash.restoreKeys.isOptedIn = { false }"
                ) == true,
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }
}
