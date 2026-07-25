import Foundation
import Testing

/// Every GUI action that ends in `reload()` drops the user's
/// staged edits, so every one must route through
/// `SettingsModel.discardingEdits` (#515). A behavioural test
/// cannot see that — it can only check the gate a call site
/// chose to use — so this guard scans the source instead.
///
/// **The lens, not the list.** A hand-enumerated "these seven
/// buttons are gated" would be fail-OPEN for the case that
/// matters: an eighth path added later appears in neither the
/// list nor the index, so nothing examines it. This guard
/// instead discovers *every* occurrence of each destructive
/// call and requires it to sit inside a `discardingEdits`
/// closure — so a new ungated call site fails on arrival. It
/// earned that design immediately: the broken-profile Delete
/// (`ProfilesSection+Broken.swift`) was a seventh path the #406
/// audit's own hand-traced list missed.
///
/// Known limit: this is lexical. A destructive call reached
/// through a helper function that is *itself* called outside a
/// gate reads as gated here. Adding one is the shape to watch.
@Suite("Discard gate call-site parity")
struct DiscardGateParityTests {
    /// The model calls whose tail is `reload()` — each drops
    /// staged edits and clears `isDirty`.
    private let destructive = [
        "model.showLuaEditor = true",
        "model.loadProfile(",
        "model.deleteProfile(",
        "model.renameProfile(",
        "model.applyStandardPreset(",
        "model.selectEditTarget(",
    ]

    /// Files excluded, each for a stated reason — fail-shut, so
    /// a new exclusion is a conscious edit rather than a gap.
    private let exempt: Set<String> = [
        // `adoptIntoGui` migrates the file on DISK into GUI
        // management; it never reads the editor buffer, and it
        // already carries its own confirmation naming the
        // migration. A second dialog on top would double-prompt
        // one gesture.
        "LuaEditorTab.swift"
    ]

    @Test("every destructive call sits inside the gate")
    func destructiveCallsAreGated() throws {
        var seen = 0
        for file in try swiftSources(under: settingsDir)
        where !exempt.contains(file.lastPathComponent) {
            let source = stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let gated = gateClosures(in: source)
                .joined(separator: "\n")
            for call in destructive {
                let total = source.count(of: call)
                guard total > 0 else { continue }
                seen += total
                #expect(
                    gated.count(of: call) == total,
                    Comment(
                        rawValue:
                            "ungated discard path: \(call) in "
                            + file.lastPathComponent
                    )
                )
            }
        }
        // A scan that matches nothing passes vacuously — the
        // failure mode that let the sidebar-search guard sit
        // blind. Six of the seven gated paths live outside the
        // exempt file.
        #expect(seen >= 6)
    }

    /// The trailing closure of every `discardingEdits(…) { … }`
    /// call, found by walking `(…)` then `{…}` nesting. A flat
    /// regex cannot do this: the argument list spans lines and
    /// contains its own braces and parens inside `L(…)` strings.
    private func gateClosures(in source: String) -> [String] {
        let text = Array(source)
        let needle = Array("discardingEdits")
        var found: [String] = []
        var i = 0
        while i + needle.count <= text.count {
            guard Array(text[i..<(i + needle.count)]) == needle
            else {
                i += 1
                continue
            }
            var cursor = i + needle.count
            guard
                balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                ) != nil,
                let body = balanced(
                    text,
                    from: &cursor,
                    open: "{",
                    close: "}"
                )
            else {
                i += needle.count
                continue
            }
            found.append(body)
            i = cursor
        }
        return found
    }

    /// Consumes whitespace then a balanced `open`…`close` run,
    /// returning its interior. String literals are skipped so a
    /// brace or paren inside one cannot unbalance the walk.
    private func balanced(
        _ text: [Character],
        from cursor: inout Int,
        open: Character,
        close: Character
    ) -> String? {
        var i = cursor
        while i < text.count, text[i].isWhitespace { i += 1 }
        guard i < text.count, text[i] == open else { return nil }
        var depth = 0
        let start = i + 1
        while i < text.count {
            let character = text[i]
            if character == "\"" {
                i += 1
                while i < text.count, text[i] != "\"" {
                    if text[i] == "\\" { i += 1 }
                    i += 1
                }
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    cursor = i + 1
                    return String(text[start..<i])
                }
            }
            i += 1
        }
        return nil
    }

    /// Cuts each line at its first `//`, so a comment naming a
    /// destructive call cannot register as one.
    private func stripComments(_ source: String) -> String {
        source
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { line -> Substring in
                if let slash = line.range(of: "//") {
                    return line[..<slash.lowerBound]
                }
                return line
            }
            .joined(separator: "\n")
    }

    private var settingsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func swiftSources(
        under directory: URL
    ) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        return files
    }
}

extension String {
    /// Non-overlapping occurrences of `needle`.
    fileprivate func count(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var total = 0
        var cursor = startIndex
        while let found = range(
            of: needle,
            range: cursor..<endIndex
        ) {
            total += 1
            cursor = found.upperBound
        }
        return total
    }
}
