import Foundation
import Testing

/// A preset's settings are merged in ONE place (#1663):
/// `StandardLayout.settings(sizes:)` lays the preset's own leaves
/// over the shape tuning, and `StarterSetup` is the one door to
/// `StarterTuning.settings`. A caller that reads the raw
/// tuning or calls `StarterTuning` itself is a second merge.
@Suite("Preset shape tuning seam (#1663)")
struct PresetShapeTuningSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let home = "StandardLayout+Tuning.swift"

    private func core() throws -> [URL] {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        #expect(!files.isEmpty)
        return files
    }

    private func count(_ needle: String, in files: [URL]) throws
        -> [String: Int]
    {
        var hits: [String: Int] = [:]
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            let n = text.components(separatedBy: needle).count - 1
            if n > 0 { hits[file.lastPathComponent] = n }
        }
        return hits
    }

    @Test("the raw tuning is read only by the merge")
    func tuningHasOneReader() throws {
        let files = try core()
        #expect(files.contains { $0.lastPathComponent == Self.home })
        var readers = try count(".tuning", in: files)
        // A second merge in another extension reads it bare.
        for needle in ["switch tuning", "case .preset", "case .resolved"] {
            for (file, n) in try count(needle, in: files)
            where file != Self.home {
                readers[file, default: 0] += n
            }
        }
        #expect(readers.isEmpty, .init(rawValue: "\(readers)"))
        let home = try #require(
            files.first { $0.lastPathComponent == Self.home }
        )
        let text = try SourceScan.strippedSource(at: home)
        #expect(text.contains("switch tuning"))
    }

    @Test("StarterTuning is reached through the one door")
    func starterTuningHasOneCaller() throws {
        let callers = try count("StarterTuning.settings(", in: core())
        #expect(callers == ["StarterSetup.swift": 1])
    }

    /// Both the apply door and the monitor-change fallback reach
    /// the settings through the composition.
    @Test("the composition hands the merge the ordered screens")
    func compositionTakesTheMerge() throws {
        let file = try #require(
            try core().first {
                $0.lastPathComponent == "ProfileComposition.swift"
            }
        )
        let squashed = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(
            squashed.contains(
                "settings:layout.settings(sizes:ordered.map(\\.frame.size))"
            )
        )
    }
}
