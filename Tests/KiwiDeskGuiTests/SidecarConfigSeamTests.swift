import Foundation
import Testing

/// The draft reaches gui.json only as `sidecarConfig` (#1393).
///
/// On the loaded profile's page the draft holds the rules that
/// profile RESOLVES — the shared ones and its own — so writing
/// `config` itself would bake one profile's own rules into the
/// base every profile inherits, with every behaviour test green
/// until someone opens a second profile. The census names each
/// GUI file that writes gui.json and how many writes it holds, so
/// a new writer must be counted here, and every write must pass
/// `sidecarConfig`.
@Suite("gui.json writes take sidecarConfig (#1393)")
struct SidecarConfigSeamTests {
    private let doors = ["saveGuiConfig(", "guiConfigStore.save("]

    /// File basename → gui.json writes of the draft it holds.
    private let writers: [String: Int] = [
        // The paused globals save: the store (cold boot) and the
        // core's save.
        "SettingsModel+Globals.swift": 2,
        // The draft commit's globals half.
        "SettingsModel+Profiles.swift": 1,
    ]

    private var files: [(name: String, source: String)] {
        get throws {
            let root = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk")
            return try SourceScan.swiftSources(under: root).map {
                (
                    $0.lastPathComponent,
                    SourceScan.stripComments(
                        try String(contentsOf: $0, encoding: .utf8)
                    )
                )
            }
        }
    }

    @Test("every GUI gui.json write is counted")
    func writersAreCounted() throws {
        var counts: [String: Int] = [:]
        for (name, source) in try files {
            let hits = doors.reduce(0) { $0 + source.occurrences(of: $1) }
            if hits > 0 { counts[name] = hits }
        }
        #expect(
            counts == writers,
            Comment(
                rawValue:
                    "a GUI file gained or lost a gui.json write; register it "
                    + "here, passing sidecarConfig (#1393)"
            )
        )
    }

    /// A door that writes the draft to gui.json refuses first when
    /// the live page moved (#1393) — a third door without the check
    /// splits a Save between two profiles.
    @Test("each writing door checks the page first")
    func writersCheckThePage() throws {
        for (name, source) in try files where writers[name] != nil {
            #expect(
                source.occurrences(of: "pageMovedReason")
                    == source.occurrences(of: "saveGuiConfig(sidecarConfig)"),
                Comment(
                    rawValue: "\(name): a gui.json door without the page check"
                )
            )
        }
    }

    /// And the check comes FIRST — ahead of any draft change or
    /// write in its door — or a refused Save still mutates.
    @Test("the page check precedes every change and write")
    func pageCheckComesFirst() throws {
        for (name, source) in try files where writers[name] != nil {
            guard let check = source.range(of: "pageMovedReason") else {
                continue
            }
            for later in ["mergeLiveSpaces(", "saveRuleReach()"] {
                guard let at = source.range(of: later) else { continue }
                #expect(
                    check.lowerBound < at.lowerBound,
                    Comment(
                        rawValue:
                            "\(name): \(later) runs before the page check"
                    )
                )
            }
        }
    }

    @Test("each write passes sidecarConfig")
    func writesPassSidecarConfig() throws {
        for (name, source) in try files {
            let hits = doors.reduce(0) { $0 + source.occurrences(of: $1) }
            let routed = doors.reduce(0) {
                $0 + source.occurrences(of: $1 + "sidecarConfig)")
            }
            #expect(
                hits == routed,
                Comment(
                    rawValue:
                        "\(name) writes gui.json from something other than "
                        + "sidecarConfig — on the loaded page that bakes "
                        + "its own rules into the shared base (#1393)"
                )
            )
        }
    }
}
