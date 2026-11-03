import Foundation
import Testing

/// A reply key names one concept across every query reply and event
/// (#2963, `docs/design-decisions.md` ▸ *Each query reply owns its
/// fields, and a concept has one key*): a key spelled with two
/// `JSONValue` cases anywhere in Core reds until it is renamed or
/// given its reason in `exempt`, and a retired key reds wherever it
/// is spelled again. Reads only a value written as a bare case —
/// `"k": .bool(` — so a value built through `.map { … } ?? .null`
/// or a helper hides its case (`focused`, a Space's window id beside
/// a window's bool, is subject-scoped and unseen for that reason),
/// and a synonym (`mode` beside `layout_mode`) is caught only once
/// it joins `retired`.
@Suite("Reply key vocabulary (#2963)")
struct ReplyKeyVocabularyTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Key → why it may take more than one case. Each is
    /// subject-scoped: the object it sits in says what it means.
    private static let exempt: [String: String] = [
        "id": "a Space's string, a window's or screen's number",
        "built_in": "the shortcut groups' list; an app's ignore flag",
        "commands": "the help listing's count; a group's verb list",
    ]

    /// Keys a rename retired; respelling one undoes #2963.
    private static let retired = [
        "floats", "layout_mode", "tiles", "ignores",
    ]

    /// Every Core file: a reply built in a new directory is read
    /// without joining a list.
    private func coreSources() throws -> [URL] {
        let urls = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Sources/KiwiDeskCore"
            )
        )
        #expect(!urls.isEmpty)
        return urls
    }

    /// Key → case → files spelling it.
    private func census() throws -> [String: [String: Set<String>]] {
        var seen: [String: [String: Set<String>]] = [:]
        for url in try coreSources() {
            let text = try SourceScan.strippedSource(at: url)
            let pattern =
                #/
                "([a-z][a-z0-9_]*)" \s* : \s* \.
                (bool|number|string|array|object) \b
                /#
            for hit in text.matches(of: pattern) {
                seen[String(hit.1), default: [:]][
                    String(hit.2),
                    default: []
                ].insert(url.lastPathComponent)
            }
        }
        return seen
    }

    @Test("no reply key takes two value kinds")
    func oneKindPerKey() throws {
        let seen = try census()
        #expect(seen.count > 50, "the scan read almost nothing")
        let mixed = seen.filter {
            $0.value.count > 1 && Self.exempt[$0.key] == nil
        }
        #expect(mixed.isEmpty, "two kinds for one key: \(mixed)")
    }

    @Test("every exemption still mixes kinds")
    func exemptionsAreLive() throws {
        let seen = try census()
        for key in Self.exempt.keys {
            #expect(
                (seen[key]?.count ?? 0) > 1,
                "\(key) no longer needs its exemption"
            )
        }
    }

    /// Any `"key":` spelling counts, whatever builds its value.
    @Test("no retired key is spelled again")
    func retiredStayRetired() throws {
        var back: [String] = []
        for url in try coreSources() {
            let text = try SourceScan.strippedSource(at: url)
            for key in Self.retired
            where text.contains(try Regex("\"\(key)\"\\s*:")) {
                back.append("\(key) in \(url.lastPathComponent)")
            }
        }
        #expect(back.isEmpty, "retired keys respelled: \(back)")
    }
}
