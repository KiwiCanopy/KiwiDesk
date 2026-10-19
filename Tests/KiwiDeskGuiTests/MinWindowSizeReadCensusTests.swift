import Foundation
import Testing

/// Every read of the minimum window size goes through the one
/// resolver, `TilingSettings.minWindowSize(for:in:)` (#2237): the
/// floor is per layout, so a raw read of the stored value answers
/// for no layout and disagrees with the one the layout draws. A
/// stored-value read outside `allowed` reds until it routes or is
/// given its reason here.
@Suite("minimum window size read census (#2237)")
struct MinWindowSizeReadCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → why it may name the stored value.
    private static let allowed: [String: String] = [
        "KiwiCore+GapCommands.swift": "the Lua setter writes it",
        "StarterTuning.swift": "the first-run seed writes it",
        "LayoutDefaultsSection.swift": "the Settings row edits it",
        "SettingsRevertRegister+Settings1.swift":
            "the row's revert writes it back",
        "HomeCardContent.swift": "the card shows the stored value",
        "HomeCardPlate.swift": "the card shows the stored value",
    ]

    /// Reads of the stored value in `text`: `settings.minWindowSize`
    /// not followed by `(`, which is the resolver's call.
    private static func rawReads(in text: String) -> Int {
        var count = 0
        var cursor = text.startIndex
        while let hit = text.range(
            of: "settings.minWindowSize",
            range: cursor..<text.endIndex
        ) {
            cursor = hit.upperBound
            if text[hit.upperBound...].hasPrefix("(") { continue }
            count += 1
        }
        return count
    }

    private func sources() throws -> [URL] {
        let files = try ["Sources/KiwiDeskCore", "Sources/KiwiDesk"]
            .flatMap {
                try SourceScan.swiftSources(
                    under: Self.root.appendingPathComponent($0)
                )
            }
        #expect(files.count > 100)
        return files
    }

    @Test("no raw read of the stored floor")
    func noRawRead() throws {
        var offenders: [String] = []
        for file in try sources() {
            let name = file.lastPathComponent
            guard Self.allowed[name] == nil else { continue }
            let text = try SourceScan.strippedSource(at: file)
            if Self.rawReads(in: text) > 0 { offenders.append(name) }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "raw floor read in \(offenders)")
        )
    }

    @Test("every allowed file still names it")
    func allowedIsLive() throws {
        let files = try sources()
        for name in Self.allowed.keys {
            let file = try #require(
                files.first { $0.lastPathComponent == name }
            )
            let text = try SourceScan.strippedSource(at: file)
            #expect(
                Self.rawReads(in: text) > 0,
                .init(rawValue: "\(name) no longer names it")
            )
        }
    }

    /// The layouts read the floor off `LayoutContext`, so the one
    /// builder of a Space's context must fill it from the resolver
    /// for that Space's own layout.
    @Test("the layout context takes the Space's own floor")
    func contextTakesTheResolver() throws {
        let file = try #require(
            sources().first {
                $0.lastPathComponent
                    == "TilingSettings+Resolution.swift"
            }
        )
        let text = try SourceScan.strippedSource(at: file)
        #expect(
            text.contains(
                "minWindowSize: minWindowSize(for: space.mode, "
                    + "in: space.id)"
            )
        )
    }
}
