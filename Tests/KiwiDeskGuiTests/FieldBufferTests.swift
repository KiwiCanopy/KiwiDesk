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

    /// Every settings field buffer's outside-change hook re-seeds
    /// through the one verdict.
    @Test(
        "each buffer's outside-change hook reads the verdict",
        arguments: [
            ("Common/StepperRow.swift", ".onChange(of: value)"),
            ("Common/ColorField.swift", ".onChange(of: hex)"),
            ("Common/SlotCountRow.swift", ".onChange(of: size)"),
            ("Layouts/MinSizeFields.swift", ".onChange(of: value)"),
        ]
    )
    func sitesReadTheVerdict(file: String, hook: String) throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/\(file)"
                )
        )
        let chars = Array(source)
        let start = try #require(source.range(of: hook))
        var cursor = source.distance(
            from: source.startIndex,
            to: start.upperBound
        )
        let body = try #require(
            SourceScan.balanced(chars, from: &cursor, open: "{", close: "}")
        )
        #expect(body.contains("FieldBuffer.follows("))
        #expect(!body.contains("!focused"))
    }
}
