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

    /// Every `.label` READ in a binding-handling file outside the
    /// home, by file, exact count and reason. Keyed on the subject
    /// rather than on how it is compared: any new read reds until
    /// it is routed through the door or classified here.
    private let allowed: [String: (count: Int, reason: String)] = [
        "KeybindingAppGroup+Row.swift": (
            4,
            "an application row's label IS the picked app's name; "
                + "empty picks the picker's placeholder"
        ),
        "KeybindingAppGroup.swift": (
            2,
            "application rows sort by their app-name label"
        ),
        "ShortcutsReference+Bands.swift": (
            3,
            "an application row's app-name label when no bundle id "
                + "names it, and the rows' sort by that name"
        ),
        "KeybindingImportClassifier.swift": (
            5,
            "a NavCommand's or shape's label WRITTEN into a binding: "
                + "the stored identifier, never displayed"
        ),
        "KeybindingCatalog+Layers.swift": (
            1,
            "a NavCommand's label written into a binding on rename"
        ),
        "KeybindingNavRow.swift": (
            1,
            "a NavCommand's label stored on the binding it creates"
        ),
        "KeyboardHoverReading.swift": (
            1,
            "a KeyLayer's chord label, not a binding's"
        ),
        "KeyboardCensus.swift": (
            1,
            "a KeyLayer's chord label, not a binding's"
        ),
        "ShortcutsPanelController+Reference.swift": (
            1,
            "a built ShortcutRow's display label"
        ),
    ]

    /// A file is in scope when it can hold a binding: it names the
    /// type, the reach templates, or a binding. Lookaheads, not
    /// `\b`: Swift's Unicode word boundary does not break inside
    /// `label.count`.
    private let scope = /KeyBinding|keyTemplates|binding|\.kept(?!\w)/

    /// A `.label` member read — `x.label`, `$0.label`, `x?.label`,
    /// `t[k]?.label` — but not an assignment to one.
    private let labelRead = /\.label(?!\w)(?!\s*=[^=])/

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

    /// Label reads per in-scope file, literals and comments blanked
    /// so a localization key spelling `.label` is no read.
    private func labelReads() throws -> [String: Int] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var result: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.blankedSource(at: file)
            guard text.firstMatch(of: scope) != nil else { continue }
            let reads = reads(in: text)
            if reads > 0 { result[file.lastPathComponent] = reads }
        }
        return result
    }

    private func reads(in text: String) -> Int {
        text.matches(of: labelRead).count
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

    @Test("the label needle reads the subject, however it is spelled")
    func labelNeedleFailsClosed() {
        let reads = [
            "t.map { KeybindingCatalog.localizedLabel(for: $0.label) }",
            "let n = row?.label ?? \"\"\nreturn n.isEmpty ? k.lua : n",
            "binding.label != \"\" ? binding.label : binding.lua",
            "templates[key]?.label.count == 0",
        ]
        for read in reads {
            #expect(self.reads(in: read) > 0, "unmatched: \(read)")
        }
        // A write is no read, and neither is a longer member.
        #expect(self.reads(in: "binding.label = command.lua") == 0)
        #expect(self.reads(in: "view.labelsHidden()") == 0)
        // Scope admits a file that only reaches templates.
        #expect("reach.keyTemplates[rival]".firstMatch(of: scope) != nil)
    }

    @Test("every binding label read is routed or classified")
    func everyLabelReadIsClassified() throws {
        let found = try labelReads()
        // Non-vacuous: the classified files are really scanned.
        #expect(found.count >= allowed.count)
        for (name, count) in found where name != home {
            let message =
                "\(name) reads .label \(count)x: name the binding "
                + "through KeybindingCatalog.localizedName, or "
                + "classify the read with its reason"
            #expect(allowed[name]?.count == count, "\(message)")
        }
        for (name, entry) in allowed {
            #expect(found[name] == entry.count, "\(name): stale")
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
