import Foundation
import Testing

/// A `KeyBinding` is named for display through ONE door,
/// `KeybindingCatalog.localizedName(of:config:)` (#2111, #96): a
/// hand-written "label, else Lua" shows the stored English
/// identifier in every locale. The scan covers `Sources/KiwiDesk`;
/// Core's conflict naming is #2116's.
@Suite("Binding name door (#2111)")
struct BindingNameDoorTests {
    private let home = "KeybindingCatalog+DisplayName.swift"

    /// Files whose label reads are not a binding's name, with how
    /// many hits each holds and why.
    private let allowed: [String: (count: Int, reason: String)] = [
        "KeybindingAppGroup+Row.swift": (
            2,
            "an application row's label IS the picked app's name; "
                + "empty chooses the picker's placeholder"
        )
    ]

    /// The hand-written spellings of "the label, else something":
    /// an emptiness test of a label, or a label and a Lua/combo as
    /// the two arms of one ternary or coalesce.
    private let namingSpellings: [String] = [
        #"label\.isEmpty"#,
        #"\.label\s*==\s*"""#,
        #"""\s*==\s*[\w.?\[\]]*\.label\b"#,
        #"\.label\.count\s*==\s*0"#,
        // A coalesced label only counts beside a Lua/combo arm: a
        // `Mirror` child's optional label is no binding.
        #"\.label\s*\?\?[^;{}]{0,200}?\.(lua|combo)\b"#,
        #"\?\s*[\w.?\[\]()<>"]*\.(lua|combo)\s*:\s*[\w.?\[\]]*\.label\b"#,
        #"\?\s*[\w.?\[\]]*\.label\s*:\s*[\w.?\[\]()<>"]*\.(lua|combo)\b"#,
    ]

    /// A binding's label handed to the label-keyed resolver.
    private let resolverSpelling =
        #"localizedLabel\(\s*for:\s*[\w.?\[\]]+\.label\s*(\?\?\s*""\s*)?,"#

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

    private func hits(_ spellings: [String], in text: String) throws
        -> Int
    {
        try spellings.reduce(0) {
            $0 + text.matches(of: try Regex($1)).count
        }
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
        // The fallback the door owns is in the door's own body.
        let door = try #require(doors.first).text
        let start = try #require(
            door.range(of: "static func localizedName(")
        )
        let end = try #require(
            door.range(
                of: "static func namedCommands(",
                range: start.upperBound..<door.endIndex
            )
        )
        let body = door[start.upperBound..<end.lowerBound]
        #expect(body.contains("binding.label.isEmpty"))
        #expect(body.contains("?? binding.lua"))
    }

    @Test("the naming needles match every spelling they target")
    func namingNeedlesFailClosed() throws {
        let reverted = [
            "x.label.isEmpty ? x.lua : x.label",
            "if !binding.label.isEmpty { return binding.label }",
            "binding.label == \"\" ? binding.lua : binding.label",
            "\"\" == binding.label",
            "holder.label.count == 0",
            "let n = row?.label ?? \"\"\nreturn n.isEmpty\n"
                + "    ? RuleReachTable<String>.keyParts(key).lua : n",
            "flag ? holder.lua : holder.label",
            "flag ? t[k]?.label : RuleReachTable<String>.keyParts(k).lua",
            "flag ? entry.kept.label : entry.kept.combo",
        ]
        for spelling in reverted {
            #expect(
                try hits(namingSpellings, in: spelling) > 0,
                "unmatched: \(spelling)"
            )
        }
        let resolver = try Regex(resolverSpelling)
        for spelling in [
            "localizedLabel(for: entry.binding.label,",
            "localizedLabel(\n for: x?.label ?? \"\",",
            "localizedLabel(for: reach.keyTemplates[k]?.label ?? \"\",",
        ] {
            #expect(
                spelling.firstMatch(of: resolver) != nil,
                "unmatched: \(spelling)"
            )
        }
        // And a label STRING handed in stays legal.
        #expect("localizedLabel(for: who,".firstMatch(of: resolver) == nil)
    }

    @Test("no file names a binding around the door")
    func noHandWrittenNaming() throws {
        var seen: [String: Int] = [:]
        for (name, text) in try sources() where name != home {
            let count = try hits(namingSpellings, in: text)
            guard count > 0 else { continue }
            seen[name] = count
            let message =
                "\(name) names a label by hand \(count)x: name the "
                + "binding through KeybindingCatalog.localizedName"
            #expect(allowed[name]?.count == count, "\(message)")
        }
        // Every exemption still answers a real read, or it is stale.
        for (name, entry) in allowed {
            #expect(seen[name] == entry.count, "\(name): stale")
        }
    }

    @Test("no call hands a binding's raw label to the label resolver")
    func noLabelResolverOnABinding() throws {
        let pattern = try Regex(resolverSpelling)
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
