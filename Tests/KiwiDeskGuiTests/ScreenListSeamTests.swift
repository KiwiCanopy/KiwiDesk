import Foundation
import Testing

/// **Tiling reads the screens through `ScreenList` alone, and
/// both test cores memoize it** (#1894): a live `NSScreen` read
/// on every retile was ~15 % of the Core target's blocked
/// main-thread samples. A read beside the door escapes the memo
/// silently, so the door is the one spelling in `Tiling/`.
@Suite("Screen list seam (#1894)")
struct ScreenListSeamTests {
    private static let door = "Tiling/ScreenList.swift"

    @Test("Tiling spells NSScreen.screens and .main only in the door")
    func tilingReadsThroughTheDoor() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Tiling")
        var scanned = 0
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let name = "Tiling/" + file.lastPathComponent
            guard name != Self.door else { continue }
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("NSScreen.screens")
                || source.contains("NSScreen.main")
            {
                offenders.append(name)
            }
        }
        #expect(scanned > 20, "scanned \(scanned) files")
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test("both twins memoize the list, and the door consults it")
    func twinsMemoizeTheList() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let text = try String(
                contentsOf: repo.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                ),
                encoding: .utf8
            )
            let memo = try #require(
                text.range(of: "ScreenList.override =")
                    .map { String(text[$0.upperBound...].prefix(200)) },
                .init(rawValue: "\(target) misses the memo")
            )
            #expect(
                memo.contains("testScreens = live"),
                .init(rawValue: "\(target)'s override does not memoize")
            )
        }
        let door = try SourceScan.strippedSource(
            at: repo.appendingPathComponent(
                "Sources/KiwiDeskCore/\(Self.door)"
            )
        )
        #expect(
            door.components(separatedBy: "if let override").count == 3
        )
    }
}
