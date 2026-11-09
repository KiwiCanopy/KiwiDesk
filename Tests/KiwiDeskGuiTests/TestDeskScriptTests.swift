import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `scripts/test-desk` and the app agree on the test desk (#3121):
/// the defaults suite `down` deletes is the one the app writes, and
/// the keys `up` seeds past the first-run tour are the app's own.
/// A drifted name leaves the suite behind, or the tour up.
@Suite("Test desk script parity (#3121)")
struct TestDeskScriptTests {
    private static let script = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("scripts/test-desk")

    @Test("the script names the app's suite and seeds its keys")
    func scriptMatchesTheApp() throws {
        let text = try String(contentsOf: Self.script, encoding: .utf8)
        #expect(text.contains("SUITE=\"\(TestDesk.defaultsSuite)\""))
        for key in [
            TilingConsent.key, OnboardingDiscovery.key,
            WhatsNewRecord.lastRunKey,
        ] {
            #expect(
                text.contains("defaults write \"$SUITE\" \(key) "),
                "\(key) is not seeded"
            )
        }
    }

    /// A bundle with an id and a feed, which an updater takes.
    private static func fedBundle() throws -> Bundle {
        let app = testTemporaryDirectory.appendingPathComponent(
            "Fed-\(UUID().uuidString).app"
        )
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "CFBundleIdentifier": "org.kiwidesk.fed-probe",
            "SUFeedURL": "https://example.invalid/appcast.xml",
        ]
        try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ).write(to: contents.appendingPathComponent("Info.plist"))
        return try #require(Bundle(url: app))
    }

    @Test("a test desk takes no updater, a fed bundle otherwise does")
    @MainActor
    func noUpdaterOnATestDesk() throws {
        let fed = try Self.fedBundle()
        #expect(AppUpdaterFactory.isBundled(fed, testDesk: false))
        #expect(!AppUpdaterFactory.isBundled(fed, testDesk: true))
    }
}
