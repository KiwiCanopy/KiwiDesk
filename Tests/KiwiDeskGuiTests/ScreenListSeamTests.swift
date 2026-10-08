import Foundation
import Testing

/// **Core reads the screens through `ScreenList` alone, and both
/// test cores memoize it** (#1894): a live `NSScreen` read on
/// every retile was ~15 % of the Core target's blocked
/// main-thread samples, and a read beside the door both escapes
/// the memo and gives a test core a second answer to "which
/// screen is main". The door is the one spelling in Core.
@Suite("Screen list seam (#1894)")
struct ScreenListSeamTests {
    private static let door = "Tiling/ScreenList.swift"

    @Test("Core spells NSScreen.screens and .main only in the door")
    func coreReadsThroughTheDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var scanned = 0
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let name =
                file.path.components(
                    separatedBy: "Sources/KiwiDeskCore/"
                ).last ?? file.path
            guard name != Self.door else { continue }
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("NSScreen.screens")
                || source.contains("NSScreen.main")
            {
                offenders.append(name)
            }
        }
        #expect(scanned > 500, "scanned \(scanned) files")
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("both twins memoize the list, and the door consults it")
    func twinsMemoizeTheList() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let text = try SourceScan.strippedSource(
                at: repo.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
            )
            let memo = try #require(
                text.range(of: "ScreenList.override =")
                    .map { String(text[$0.upperBound...].prefix(200)) },
                .init(rawValue: "\(target) misses the memo")
            )
            // Both halves: a memo written and never read back
            // re-reads the machine every call.
            #expect(
                memo.contains("if let known = testScreens")
                    && memo.contains("return known")
                    && memo.contains("testScreens = live"),
                .init(rawValue: "\(target)'s override does not memoize")
            )
        }
        let door = try SourceScan.strippedSource(
            at: repo.appendingPathComponent(
                "Sources/KiwiDeskCore/\(Self.door)"
            )
        )
        // Each read ANSWERS from the override, not just tests it:
        // `all` the list, `main` and `mainOrFirst` its first.
        #expect(door.occurrences(of: "return override() }") == 1)
        #expect(door.occurrences(of: "return override().first }") == 2)
    }
}
