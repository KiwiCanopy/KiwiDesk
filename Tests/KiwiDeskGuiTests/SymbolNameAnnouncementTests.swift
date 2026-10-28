import Foundation
import Testing

/// No Settings control announces an SF Symbol's own name.
///
/// VoiceOver reads an unlabelled `Image(systemName:)` by the
/// symbol's description in the SYSTEM language, so on a German Mac
/// the App Rules trash read "Papierkorb" and the Spaces drag handle
/// "Bewegen" under an English KiwiDesk (device AX read, 2026-10-20).
/// A borderless `Menu` takes its AX title from its label, so an
/// `.accessibilityLabel` on the menu does not displace the
/// symbol's name; the label itself has to carry the words.
///
/// Off the main actor: it reads files and counts.
@Suite("Settings symbols never announce their own name")
struct SymbolNameAnnouncementTests {
    private static let settings =
        SourceScan
        .repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    /// The modifier chain hanging off the expression that starts
    /// at `start`: every following line that opens with `.`, or
    /// that sits inside an argument list the chain opened.
    private func chain(in lines: [Substring], from start: Int) -> String {
        var out = [String(lines[start])]
        var depth = lines[start].reduce(0) { $0 + delta($1) }
        var i = start + 1
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.drop { $0.isWhitespace }
            guard depth > 0 || trimmed.hasPrefix(".") else { break }
            out.append(String(line))
            depth += line.reduce(0) { $0 + delta($1) }
            i += 1
        }
        return out.joined(separator: "\n")
    }

    private func delta(_ c: Character) -> Int {
        c == "(" ? 1 : c == ")" ? -1 : 0
    }

    /// A drag handle is mouse-only and its row names the thing it
    /// moves, so it is hidden from VoiceOver, as `LayoutCycleList`'s
    /// handle already was.
    @Test func dragHandlesAreSilent() throws {
        var handles = 0
        for url in try SourceScan.swiftSources(under: Self.settings) {
            let lines = try SourceScan.strippedSource(at: url)
                .split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated()
            where line.contains(#"Image(systemName: "line.3.horizontal")"#) {
                handles += 1
                #expect(
                    chain(in: lines, from: i)
                        .contains(".accessibilityHidden(true)"),
                    "\(url.lastPathComponent):\(i + 1) announces its symbol"
                )
            }
        }
        #expect(handles >= 3, "the scan found no handles")
    }

    /// The App Rules trash menu names itself through its label.
    @Test func trashMenuNamesItself() throws {
        let url = Self.settings
            .appendingPathComponent("Components/Common/AppRuleIdentity.swift")
        let source = try SourceScan.strippedSource(at: url)
        let start = try #require(source.range(of: "func menu("))
        let tail = source[start.upperBound...]
        let end = tail.range(of: "\n    }\n")?.lowerBound ?? tail.endIndex
        let body = tail[..<end]
        #expect(body.contains(".menuStyle(.borderlessButton)"))
        #expect(body.contains(#"Label(help, systemImage: "trash")"#))
        #expect(!body.contains(#"Image(systemName: "trash")"#))
    }
}
