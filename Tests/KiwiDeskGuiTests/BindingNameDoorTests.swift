import Foundation
import Testing

/// A `KeyBinding` is named for display through ONE door,
/// `KeybindingCatalog.localizedName(of:config:)` (#2111, #96): a
/// hand-written "label, else Lua" shows the stored English
/// identifier in every locale.
@Suite("Binding name door (#2111)")
struct BindingNameDoorTests {
    private let home = "KeybindingCatalog+DisplayName.swift"

    /// Files whose `label.isEmpty` reads are not a binding's name,
    /// with how many each holds and why.
    private let allowed: [String: (count: Int, reason: String)] = [
        "KeybindingAppGroup+Row.swift": (
            2,
            "an application row's label IS the picked app's name; "
                + "empty chooses the picker's placeholder"
        ),
        "SettingsValueReadout+ShortcutsGlyphs.swift": (
            1,
            "the diff readout names catalog commands from BOTH "
                + "configs' resolved map first; what is left is a "
                + "label no catalog command carries"
        ),
    ]

    private func sources() throws -> [(name: String, text: String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        return try files.map {
            (
                $0.lastPathComponent,
                SourceScan.stripComments(
                    try String(contentsOf: $0, encoding: .utf8)
                )
            )
        }
    }

    private func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("the door is declared once, in its home")
    func doorHasOneHome() throws {
        let files = try sources()
        let doors = files.filter {
            $0.text.firstMatch(
                of: /static func localizedName\(\s*of binding: KeyBinding/
            ) != nil
        }
        #expect(doors.map(\.name) == [home])
        // The fallback the door owns is really there to scan for.
        let door = try #require(doors.first)
        #expect(count("label.isEmpty", in: door.text) >= 1)
    }

    @Test("no file names a binding around the door")
    func noHandWrittenNaming() throws {
        var seen: [String: Int] = [:]
        for (name, text) in try sources() where name != home {
            let hits = count("label.isEmpty", in: text)
            guard hits > 0 else { continue }
            seen[name] = hits
            let message =
                "\(name) reads label.isEmpty \(hits)x: name the "
                + "binding through KeybindingCatalog.localizedName"
            #expect(allowed[name]?.count == hits, "\(message)")
        }
        // Every exemption still answers a real read, or it is stale.
        for (name, entry) in allowed {
            #expect(seen[name] == entry.count, "\(name): stale")
        }
    }

    @Test("no call hands a binding's raw label to the label resolver")
    func noLabelResolverOnABinding() throws {
        let pattern = /localizedLabel\(\s*for:\s*[\w.\[\]]+\.label\s*,/
        for (name, text) in try sources() where name != home {
            #expect(
                text.firstMatch(of: pattern) == nil,
                "\(name): pass the KeyBinding to localizedName(of:)"
            )
        }
    }

    @Test("every recorder preflight names its holder in the page's config")
    func preflightTakesTheModelConfig() throws {
        var calls = 0
        for (name, text) in try sources() {
            var rest = text.startIndex
            while let hit = text.range(
                of: "RecorderPreflight.rejection(",
                range: rest..<text.endIndex
            ) {
                calls += 1
                rest = hit.upperBound
                let commit = text.range(
                    of: "commit:",
                    range: rest..<text.endIndex
                )
                let args = text[rest..<(commit?.lowerBound ?? rest)]
                #expect(
                    args.contains("config: model.config"),
                    "\(name): pass the page's model.config"
                )
            }
        }
        #expect(calls >= 3)
    }

    @Test("the reach column hands RuleReachControl the localized subject")
    func reachColumnPassesSubject() throws {
        let text = try #require(
            try sources().first {
                $0.name == "KeyReachColumn.swift"
            }
        ).text
        let start = try #require(text.range(of: "var body: some View"))
        let rest = start.upperBound..<text.endIndex
        let end = try #require(
            text.range(of: "var key: String", range: rest)
        )
        let body = text[start.upperBound..<end.lowerBound]
        #expect(body.contains("RuleReachControl("))
        #expect(body.contains("subject: subject,"))
        let subject = try #require(
            text.range(of: "var subject: String {")
        )
        let trash = try #require(
            text.range(of: "struct KeyReachTrash")
        )
        let property = text[subject.upperBound..<trash.lowerBound]
        #expect(property.contains("KeybindingCatalog.localizedName("))
    }
}
