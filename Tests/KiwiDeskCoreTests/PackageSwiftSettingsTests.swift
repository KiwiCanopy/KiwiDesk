import Foundation
import Testing

/// Every Swift target compiles the one dialect `Package.swift`'s
/// shared `swiftSettings` list states (#1780): a target left
/// without it would run its async functions under other
/// isolation rules than the code it calls, and build green.
@Suite("Package.swift: one Swift dialect")
struct PackageSwiftSettingsTests {
    /// Each target declaration in `manifest`, from its opener to
    /// the next, and the ones missing the shared list. Every
    /// target but Vendor/'s C, which swiftSettings does not
    /// reach; a target with no `path:` is Swift under
    /// Sources/<Name>, so it is checked rather than skipped.
    private static func scan(
        _ manifest: String
    ) -> (targets: Int, missing: [Substring]) {
        // Any target kind, however spaced: a missed opener would
        // fold its target into the neighbour's slice.
        let opener = /\.(\w*[tT]arget|macro|plugin)\s*\(/
        let starts = manifest.matches(of: opener)
            .map(\.range.lowerBound)
        let swift = zip(starts, starts.dropFirst() + [manifest.endIndex])
            .map { manifest[$0..<$1] }
            .filter { !$0.contains(#"path: "Vendor/"#) }
        let missing = swift.filter {
            !$0.contains("swiftSettings: swiftSettings")
        }
        return (swift.count, missing)
    }

    @Test("Every Swift target takes the shared swiftSettings")
    func everySwiftTargetTakesTheList() throws {
        let manifest = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let scan = Self.scan(manifest)
        #expect(scan.targets >= 4, "too few targets parsed")
        for target in scan.missing {
            #expect(
                Bool(false),
                "\(target.prefix(80)) compiles another dialect"
            )
        }
    }

    /// The scan flags a target declared the usual way, with no
    /// `path:`, and leaves the C target alone.
    @Test("A pathless target without the list is caught")
    func pathlessTargetIsCaught() {
        let manifest = """
            .target(name: "CLua", path: "Vendor/CLua"),
            .target(name: "A", swiftSettings: swiftSettings),
            .executableTarget(name: "Tool"),
            .testTarget (name: "Spaced", swiftSettings: swiftSettings),
            .macro(name: "M"),
            """
        let scan = Self.scan(manifest)
        #expect(scan.targets == 4)
        #expect(
            scan.missing.map { $0.prefix(30) }.joined()
                .contains("Tool")
        )
        #expect(scan.missing.count == 2)
    }
}
