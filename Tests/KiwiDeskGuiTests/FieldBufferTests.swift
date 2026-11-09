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
    /// an `.onChange` of anything but focus whose body reads
    /// `focused` — goes through the one verdict, found by a sweep so
    /// a new buffered field cannot go bare.
    @Test("every buffer's outside-change hook reads the verdict")
    func sitesReadTheVerdict() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sites: [String] = []
        for url in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: url)
            for body in Self.bufferHooks(in: source) {
                let file = url.lastPathComponent
                sites.append(file)
                #expect(
                    Self.readsTheOldValue(body),
                    Comment(rawValue: "\(file) does not follow by was:")
                )
            }
        }
        // StepperRow, ColorField, SlotCountRow, MinSizeFields.
        #expect(sites.count >= 4)
    }

    /// The body calls the verdict with `was:` naming what the field
    /// last took — the hook's old value, or a local or the stored
    /// `seeded` read from it — never the new value, and the field's
    /// own focus.
    private static func readsTheOldValue(_ body: String) -> Bool {
        let head = body.prefix { $0 != "\n" }
        let params = head.split(separator: " ").map {
            $0.trimmingCharacters(in: .punctuationCharacters)
        }
        guard body.contains("focused: focused)"),
            let call = body.range(of: "FieldBuffer.follows("),
            let was = body[call.upperBound...].range(of: "was: ")
        else { return false }
        let argument = body[was.upperBound...]
            .prefix { $0 != "," && $0 != ")" }
            .trimmingCharacters(in: .whitespaces)
        if argument == "seeded" { return true }
        guard params.count >= 3, params[0] != "_" else { return false }
        let old = params[0]
        let new = params[1]
        let named = argument.contains(old) ? argument : nil
        let local = body.range(of: "let \(argument) = ").map {
            String(body[$0.upperBound..<call.lowerBound])
        }
        let source = named ?? local ?? ""
        return source.contains(old) && !source.contains(new)
    }

    /// The bodies of `.onChange(of: x)` hooks whose `x` is not a focus
    /// and whose body reads `focused`.
    private static func bufferHooks(in source: String) -> [String] {
        let chars = Array(source)
        var hooks: [String] = []
        var rest = source.startIndex
        let needle = ".onChange(of: "
        while let hit = source.range(of: needle, range: rest..<source.endIndex)
        {
            rest = hit.upperBound
            guard let close = source[hit.upperBound...].firstIndex(of: ")")
            else { break }
            let watched = source[hit.upperBound..<close]
            guard !watched.lowercased().contains("focus") else { continue }
            var cursor = source.distance(
                from: source.startIndex,
                to: source.index(after: close)
            )
            guard
                let body = SourceScan.balanced(
                    chars,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ),
                body.range(
                    of: "\\bfocused\\b",
                    options: .regularExpression
                ) != nil
            else { continue }
            hooks.append(body)
        }
        return hooks
    }
}
