import Foundation
import Testing

@testable import KiwiDesk

/// `SourceScan.segmentedPickerSource` decides what every picker
/// scan sees, so it owes a canary measured from outside its walk
/// (tests.md ▸ source-scanning primitives): every GUI file that
/// declares the picker or extends it is one the helper reads,
/// whatever the file is named or where it sits.
@Suite("Segmented picker scan canary")
struct SegmentedPickerScanCanaryTests {
    @Test("every file declaring or extending the picker is scanned")
    func nothingGoesDark() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let walker = try #require(
            FileManager.default.enumerator(atPath: root.path)
        )
        let declares = #"(extension|struct) SegmentedPicker\b"#
        var declaring: Set<String> = []
        for case let path as String in walker
        where path.hasSuffix(".swift") {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            )
            if source.range(of: declares, options: .regularExpression)
                != nil
            {
                declaring.insert(path)
            }
        }
        let scanned = Set(
            try SourceScan.segmentedPickerFiles(from: #filePath).map {
                String($0.path.dropFirst(root.path.count + 1))
            }
        )
        // The picker and its label part, at least.
        #expect(declaring.count >= 2)
        #expect(
            declaring.isSubset(of: scanned),
            "unscanned: \(declaring.subtracting(scanned))"
        )
    }

    /// The pointer and the lift are cleared when the strip is
    /// disabled and when it leaves the screen, which no fixture
    /// can drive.
    @Test("a disable and a disappear clear the pointer")
    func pointerIsCleared() throws {
        let source = try SourceScan.segmentedPickerSource(from: #filePath)
            .split(whereSeparator: \.isWhitespace).joined()
        let clears = "hoveredIndex=nilpointerIndex=nil"
        #expect(source.contains("if!now{" + clears + "}"))
        #expect(source.contains(".onDisappear{" + clears + "}"))
    }
}
