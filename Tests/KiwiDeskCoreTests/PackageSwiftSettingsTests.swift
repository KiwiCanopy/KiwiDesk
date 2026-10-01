import Foundation
import Testing

/// Every Swift target compiles the one dialect `Package.swift`'s
/// shared `swiftSettings` list states (#1780): a target left
/// without it would run its async functions under other
/// isolation rules than the code it calls, and build green.
@Suite("Package.swift: one Swift dialect")
struct PackageSwiftSettingsTests {
    /// Each target declaration, from its opener to the next.
    private func targets() throws -> [Substring] {
        let manifest = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let opener = /\.(target|executableTarget|testTarget)\(/
        let starts = manifest.matches(of: opener).map(\.range.lowerBound)
        try #require(!starts.isEmpty, "no targets parsed")
        return zip(starts, starts.dropFirst() + [manifest.endIndex])
            .map { manifest[$0..<$1] }
    }

    @Test("Every Swift target takes the shared swiftSettings")
    func everySwiftTargetTakesTheList() throws {
        // A Swift target lives under Sources/ or Tests/; Vendor/
        // is C, which swiftSettings does not reach.
        let swift = try targets().filter {
            $0.contains(#"path: "Sources/"#)
                || $0.contains(#"path: "Tests/"#)
        }
        #expect(swift.count >= 4)
        for target in swift {
            #expect(
                target.contains("swiftSettings: swiftSettings"),
                "\(target.prefix(80)) compiles another dialect"
            )
        }
    }
}
