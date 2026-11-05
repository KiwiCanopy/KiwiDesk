import Foundation
import Testing

/// What the filter answers for a change, read from its own output.
extension SiteGateRequiredTests {
    /// A file inside each entry of the workflow's own list, read here
    /// rather than typed: the list is the subject, and typing an
    /// ignored path in a suite is what `CiPathFilterTests` refuses.
    /// Deleting an entry only shortens this: the gate's
    /// `check_gate_inputs` holds the list's membership.
    private static func onePathPerInput() throws -> [String] {
        let entries = try realWorkflow()
            .split(separator: "\n")
            .drop { $0 != "    paths:" }
            .dropFirst()
            .prefix { $0.hasPrefix("      ") }
            .filter { $0.hasPrefix("      - ") }
            .map { $0.dropFirst(8).filter { $0 != "\"" } }
        try #require(!entries.isEmpty, "site.yml's list read empty")
        return entries.map {
            $0.hasSuffix("/**") ? $0.dropLast(2) + "probe.txt" : String($0)
        }
    }

    /// A workflow whose only input is `docs/**`, with `line` beside it.
    private static func listBeside(_ line: String) -> String {
        """
        on:
          push:
            paths:
              \(line)
              - "docs/**"

        """
    }

    @Test("A PR touching any site input builds")
    func inputsBuild() throws {
        for path in try Self.onePathPerInput() {
            #expect(
                try Self.verdict(changing: [path]) == "run=true",
                "\(path)"
            )
        }
    }

    @Test("An input beside other paths builds")
    func inputBesideOthersBuilds() throws {
        let input = try #require(Self.onePathPerInput().first)
        #expect(
            try Self.verdict(
                changing: ["Sources/KiwiDesk/Foo.swift", input]
            ) == "run=true"
        )
    }

    @Test("A PR leaving the site alone skips, so it cannot strand")
    func othersSkip() throws {
        for path in [
            "Sources/KiwiDeskCore/State/Foo.swift",
            "Sources/KiwiDesk/SupportLinks.swift.orig",
            "scripts/unreleased-strip2",
            "sitemap/a.txt",
            "NOTES.md",
        ] {
            #expect(
                try Self.verdict(changing: [path]) == "run=false",
                "\(path)"
            )
        }
    }

    @Test("A non-ASCII name compares as itself and a quoted one builds")
    func quotedNames() throws {
        #expect(
            try Self.verdict(changing: ["docs/Übersicht.md"]) == "run=true"
        )
        #expect(
            try Self.verdict(changing: ["other/Übersicht.md"]) == "run=false",
            "a name git would quote must not build by being quoted"
        )
        #expect(
            try Self.verdict(changing: ["other/we\"ird.md"]) == "run=true"
        )
    }

    @Test("A comment or blank line inside the list keeps the list going")
    func commentsDoNotEndTheList() throws {
        for line in ["# a note", "", "\t"] {
            #expect(
                try Self.verdict(
                    changing: ["docs/a.md"],
                    workflow: Self.listBeside(line)
                ) == "run=true",
                "after \(line)"
            )
            #expect(
                try Self.verdict(
                    changing: ["other/a.md"],
                    workflow: Self.listBeside(line)
                ) == "run=false",
                "after \(line)"
            )
        }
    }

    @Test("Every unknown builds")
    func unknownsBuild() throws {
        #expect(
            try Self.verdict(changing: ["a.swift"], event: "push")
                == "run=true"
        )
        #expect(
            try Self.verdict(
                changing: ["a.swift"],
                base: String(repeating: "0", count: 40)
            ) == "run=true",
            "an unusable base must build"
        )
        #expect(
            try Self.verdict(changing: []) == "run=true",
            "an empty diff must build"
        )
        #expect(
            try Self.verdict(
                changing: ["a.swift"],
                workflow: "name: Site\n"
            ) == "run=true",
            "an empty input list must build"
        )
    }

    @Test("An entry the filter cannot compare builds")
    func unreadableEntriesBuild() throws {
        for entry in [
            "- \"*.md\"", "- docs/old.md", "- 'docs/old.md'",
            "- \"docs/old.md\" # note", "- \"*/docs/**\"",
            "- \"[ds]ite/**\"", "- \"old/*/**\"", "- \"old+/a.md\"",
            "- \"!old/a.md\"", "- \"old/a?.md\"",
        ] {
            #expect(
                try Self.verdict(
                    changing: ["a.swift"],
                    workflow: Self.listBeside(entry)
                ) == "run=true",
                "\(entry)"
            )
        }
    }
}
