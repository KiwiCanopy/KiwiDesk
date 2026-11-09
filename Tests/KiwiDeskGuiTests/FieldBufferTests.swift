import Foundation
import Testing

@testable import KiwiDesk

/// A field's typed buffer follows an outside change unless the user
/// is mid-edit (#3098), so a live change under an open, focused
/// field neither stays hidden nor is written back on blur.
@Suite("Field buffers follow live (#3098)")
struct FieldBufferTests {
    @Test("unfocused or untouched follows, mid-edit keeps")
    func verdict() {
        #expect(FieldBuffer.follows("3", was: "3", focused: false))
        #expect(FieldBuffer.follows("7", was: "3", focused: false))
        #expect(FieldBuffer.follows("3", was: "3", focused: true))
        #expect(!FieldBuffer.follows("7", was: "3", focused: true))
    }

    /// Every GUI hook re-seeding a buffer over a value it watches —
    /// an `.onChange` of anything but a `@FocusState` whose body
    /// gates on one — goes through the one verdict, with that focus
    /// and the value the field last took. The subject is keyed on
    /// the declared `@FocusState` names, so a renamed focus is still
    /// swept. Not swept, so review's: a focus read through a helper
    /// or gated as `focused == false` / `if X { return }`; a focus
    /// declared `fileprivate` or received as `FocusState.Binding`;
    /// a buffer with no outside-change hook at all; and that
    /// `seeded` is written only by the seed.
    @Test("every buffer's outside-change hook reads the verdict")
    func sitesReadTheVerdict() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sites: [String] = []
        for url in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: url)
            let file = url.lastPathComponent
            for hook in Self.bufferHooks(in: source, file: file) {
                sites.append(file)
                #expect(
                    Self.readsTheOldValue(hook.body, focus: hook.focus),
                    Comment(rawValue: "\(file) does not follow the verdict")
                )
            }
        }
        // StepperRow, ColorField, SlotCountRow, MinSizeFields,
        // ShortcutGroupField.
        #expect(sites.count >= 5)
    }

    /// The body calls the verdict with the field's own focus and a
    /// `was:` naming what the field last took — the hook's old
    /// value, a local read from it, or the stored `seeded` — never
    /// the new value, and holds no bare `!focus` beside it.
    private static func readsTheOldValue(
        _ body: String,
        focus: String
    ) -> Bool {
        guard !body.contains("!\(focus)"),
            let arguments = callArguments(of: "FieldBuffer.follows", in: body),
            arguments.last == "focused: \(focus)",
            let was = arguments.first(where: { $0.hasPrefix("was: ") })
        else { return false }
        let argument = String(was.dropFirst("was: ".count))
        if argument == "seeded" { return true }
        let params = body.prefix { $0 != "\n" }
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        guard params.count >= 3, params[0] != "_" else { return false }
        let (old, new) = (params[0], params[1])
        let call = body.range(of: "FieldBuffer.follows(")!
        let local = body.range(of: "let \(argument) = ").map {
            String(body[$0.upperBound..<call.lowerBound])
        }
        let source = argument.contains(old) ? argument : local ?? ""
        return source.contains(old)
            && (new == "_" || !source.contains(new))
    }

    /// The top-level comma-separated arguments of the first call to
    /// `function` in `text`, trimmed.
    private static func callArguments(
        of function: String,
        in text: String
    ) -> [String]? {
        guard let hit = text.range(of: function + "(") else { return nil }
        var cursor = text.distance(
            from: text.startIndex,
            to: text.index(before: hit.upperBound)
        )
        guard
            let inside = SourceScan.balanced(
                Array(text),
                from: &cursor,
                open: "(",
                close: ")"
            )
        else { return nil }
        var parts: [String] = []
        var depth = 0
        var part = ""
        for character in inside {
            if "([{".contains(character) { depth += 1 }
            if ")]}".contains(character) { depth -= 1 }
            if character == ",", depth == 0 {
                parts.append(part)
                part = ""
            } else {
                part.append(character)
            }
        }
        parts.append(part)
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// The `.onChange(of: x)` hooks whose `x` is no `@FocusState` of
    /// the file and whose body reads one, with the focus it reads.
    private static func bufferHooks(
        in source: String,
        file: String
    ) -> [(body: String, focus: String)] {
        let focuses = matches(
            of: #"@FocusState\s+(?:private\s+)?var\s+(\w+)"#,
            in: source
        )
        guard !focuses.isEmpty else { return [] }
        let chars = Array(source)
        var hooks: [(body: String, focus: String)] = []
        var rest = source.startIndex
        while let hit = source.range(
            of: #"\.onChange\(\s*of:"#,
            options: .regularExpression,
            range: rest..<source.endIndex
        ) {
            rest = hit.upperBound
            let open = source[hit].firstIndex(of: "(")!
            var cursor = source.distance(from: source.startIndex, to: open)
            guard
                let watched = SourceScan.balanced(
                    chars,
                    from: &cursor,
                    open: "(",
                    close: ")"
                ),
                let body = SourceScan.balanced(
                    chars,
                    from: &cursor,
                    open: "{",
                    close: "}"
                )
            else {
                Issue.record("unread .onChange hook in \(file)")
                continue
            }
            let subject = watched.replacingOccurrences(of: "of:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // A hook that only moves focus is no buffer: it gates on
            // none. One calling the verdict is swept whatever focus
            // it passes, so a wrong `focused:` reds at its site.
            let gated = focuses.first(where: {
                !matches(
                    of: #"(!|focused: )\#($0)\b"#,
                    in: body,
                    whole: true
                ).isEmpty
            })
            let calls = body.contains("FieldBuffer.follows(")
            guard !focuses.contains(subject),
                let focus = gated ?? (calls ? focuses[0] : nil)
            else { continue }
            hooks.append((body, focus))
        }
        return hooks
    }

    /// The first capture group of each match, or each whole match.
    private static func matches(
        of pattern: String,
        in text: String,
        whole: Bool = false
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range(at: whole ? 0 : 1), in: text).map {
                String(text[$0])
            }
        }
    }
}
