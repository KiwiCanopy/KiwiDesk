import Foundation
import Testing

/// Every read of the minimum window size goes through the one
/// resolver, `TilingSettings.minWindowSize(for:in:)` (#2237): the
/// floor is per layout, so a raw read of the stored value answers
/// for no layout and disagrees with the one the layout draws. A
/// stored-value read (`.minWindowSizes`, or a Space's own
/// `.minWindowSizeOverride`, #2422) outside its `allowed` map reds
/// until it routes or is given its reason here.
@Suite("minimum window size read census (#2237)")
struct MinWindowSizeReadCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → why it may name the stored value.
    private static let allowed: [String: String] = [
        "TilingSettings.swift": "declares it",
        "TilingSettings+MinWindowSize.swift": "the resolver",
        "TilingSettings+Coding.swift": "decodes it",
        "TilingSettings+Encoding.swift": "encodes it",
        "KiwiCore+GapCommands.swift": "the Lua setter writes it",
        "StarterSetup.swift": "the first-run seed writes it",
        "StarterTuning.swift": "the seed's builder is named for it",
        "SettingKey+Behaviour.swift":
            "the census ids spell its stored paths",
        "SettingsModel+MinWindowSize.swift":
            "the Settings master and its rows edit it",
        "SettingsRevertRegister+Settings1.swift":
            "a row's revert writes it back",
        "SettingsValueReadout+Behaviour.swift":
            "the unsaved-changes rows compare it",
        "HomeCardContent+Subtitles.swift":
            "the card names the stored value",
    ]

    /// File → why it may name a Space's own stored floor (#2422).
    private static let overrideAllowed: [String: String] = [
        "TilingSettings.swift": "declares it",
        "TilingSettings+MinWindowSize.swift": "the resolver",
        "TilingSettings+Coding.swift": "decodes it",
        "TilingSettings+Encoding.swift": "encodes it",
        "TilingSettings+SpaceRename.swift":
            "a Space's rename, removal and restore carry it",
        "TilingSettings+SpaceOverrideReset.swift":
            "counts it among the Space's overrides",
        "KiwiCore+GapCommands.swift": "the Lua setter writes it",
        "KiwiCore+Config.swift": "a reload resets it",
        "SettingKey+Behaviour.swift":
            "the census id spells its stored path",
        "SpaceOverrideRows+MinSize.swift": "the Space's row edits it",
        "SettingsRevertRegister+Settings1.swift":
            "a row's revert writes it back",
        "SettingsValueReadout+Behaviour.swift":
            "the unsaved-changes rows compare it",
    ]

    private static let needles = [
        ("minWindowSizes", allowed),
        ("minWindowSizeOverride", overrideAllowed),
    ]

    /// Reads of the stored value: `.minWindowSizes` on any
    /// receiver, or the bare name (implicit `self`) a `TilingSettings`
    /// extension would spell. A string literal naming it ("…") is
    /// not a read, which the quote before it tells.
    private static func rawReads(
        of needle: String,
        in text: String
    ) -> Int {
        var count = 0
        var cursor = text.startIndex
        while let hit = text.range(
            of: needle,
            range: cursor..<text.endIndex
        ) {
            cursor = hit.upperBound
            let before =
                hit.lowerBound == text.startIndex
                ? " " : text[text.index(before: hit.lowerBound)]
            let after =
                hit.upperBound == text.endIndex
                ? " " : text[hit.upperBound]
            if before.isLetter || before.isNumber || before == "_"
                || before == "\"" || after.isLetter || after.isNumber
            {
                continue
            }
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
            let text = try SourceScan.strippedSource(at: file)
            for (needle, allowed) in Self.needles
            where allowed[name] == nil
                && Self.rawReads(of: needle, in: text) > 0
            {
                offenders.append("\(name) (\(needle))")
            }
        }
        #expect(
            offenders.isEmpty,
            .init(rawValue: "raw floor read in \(offenders)")
        )
    }

    @Test("every allowed file still names it")
    func allowedIsLive() throws {
        let files = try sources()
        for (needle, allowed) in Self.needles {
            for name in allowed.keys {
                let file = try #require(
                    files.first { $0.lastPathComponent == name }
                )
                let text = try SourceScan.strippedSource(at: file)
                #expect(
                    Self.rawReads(of: needle, in: text) > 0,
                    .init(rawValue: "\(name) no longer names \(needle)")
                )
            }
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
