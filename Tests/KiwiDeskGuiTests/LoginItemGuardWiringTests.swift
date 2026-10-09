import Foundation
import Testing

/// The login-item refusal holds only while the live write routes
/// through `guardedWrite` (#2094): `LoginItemRefusalTests` drives
/// that function and cannot see a `setEnabled` that bypasses it,
/// nor an onboarding wiring that never hands the model its gate.
/// Who may spell the raw write is `LoginItemSeamTests.allowed`.
@Suite("Login-item refusal stays wired (#2094)")
struct LoginItemGuardWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("setEnabled hands the live write to guardedWrite")
    func setEnabledRoutesThroughTheGuard() throws {
        let body = try SourceScan.functionBody(
            of: "setEnabled",
            in: "LoginItemManager.swift",
            under: "Service"
        )
        let flat = body.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(
            flat.occurrences(of: "guardedWrite(") == 1,
            "setEnabled no longer calls guardedWrite once"
        )
        // A fixed `.app` path here would pass every refusal.
        #expect(
            flat.occurrences(of: "at:Bundle.main.bundleURL,") == 1,
            "setEnabled no longer judges the running copy"
        )
        // Split so this file never spells the raw write itself.
        #expect(
            flat.occurrences(of: "write:service" + "Write)") == 1,
            "setEnabled no longer hands guardedWrite the live write"
        )
    }

    @Test("onboarding hands its model the copy's refusal")
    func onboardingWiresTheGate() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate+Onboarding.swift"
            )
        )
        let flat = source.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        #expect(
            flat.occurrences(
                of: "onboardingModel.loginItemUnavailable="
                    + "LoginItemManager.unavailableCopy"
            ) == 1
        )
    }
}
